library SUPD_Targeting_FHIR version '1.0.1'

/*
Statin Use in Persons with Diabetes - Targeting (SUPD)
*/

using FHIR version '4.0.0'

include FHIRHelpers version '4.0.0' called FHIRHelpers
include Participation_FHIR version '1.0.0' called Participation
include Common_FHIR version '4.10.000' called Common

codesystem "SNOMEDCT": 'urn:oid:2.16.840.1.113883.6.96'
codesystem "LOINC": 'urn:oid:2.16.840.1.113883.6.1'
codesystem "CVX": 'urn:oid:2.16.840.1.113883.12.292'

valueset "Commercial": 'http://ncqa.org/hedis/ValueSet/2.16.840.1.113762.1.4.1165.46'
valueset "DIABETES_MEDICATIONS": 'https://www.pqaalliance.org/pqa-measures/DIABETES_MEDICATIONS'
valueset "ESRD": 'https://www.pqaalliance.org/pqa-measures/ESRD'
valueset "Ethnicity": 'urn:oid:2.16.840.1.114222.4.11.837'
valueset "FERTILITY": 'https://www.pqaalliance.org/pqa-measures/FERTILITY'
valueset "Hospice Encounter": 'http://ncqa.org/hedis/ValueSet/2.16.840.1.113883.3.464.1004.1761' 
valueset "Hospice Intervention": 'http://ncqa.org/hedis/ValueSet/2.16.840.1.113883.3.464.1004.1762' // Grouper
valueset "LACTATION": 'https://www.pqaalliance.org/pqa-measures/LACTATION'
valueset "LIVER_DISEASE": 'https://www.pqaalliance.org/pqa-measures/LIVER_DISEASE'
valueset "Medicaid": 'http://ncqa.org/hedis/ValueSet/2.16.840.1.113762.1.4.1165.45'
valueset "Medicare": 'http://ncqa.org/hedis/ValueSet/2.16.840.1.113762.1.4.1165.44'
valueset "NCQA Procedure Not Done": 'http://ncqa.org/hedis/ValueSet/2.16.840.1.113883.3.464.1004.1165.996' //This is created from negation codes
valueset "ONC Administrative Sex": 'urn:oid:2.16.840.1.113762.1.4.1'
//valueset "Payer": 'urn:oid:2.16.840.1.114222.4.11.3591'
valueset "PCOS": 'https://www.pqaalliance.org/pqa-measures/PCOS'
valueset "PREDIABETES": 'https://www.pqaalliance.org/pqa-measures/PREDIABETES'
valueset "PREGNANCY": 'https://www.pqaalliance.org/pqa-measures/PREGNANCY'
valueset "Race": 'urn:oid:2.16.840.1.114222.4.11.836'
valueset "RHABDOMYOLYSIS_MYOPATHY": 'https://www.pqaalliance.org/pqa-measures/RHABDOMYOLYSIS_MYOPATHY'
valueset "SNP": 'http://ncqa.org/hedis/ValueSet/2.16.840.1.113762.1.4.1165.43'
valueset "STATINS": 'https://www.pqaalliance.org/pqa-measures/STATINS'

code "Birth date": '21112-8' from "LOINC" display 'Birth date'

/*
This library has an explicit parameter which is the product line.
Recognized normal arguments are {'commercial', 'medicaid', 'medicare'}.
If one of these normal arguments is given, the patient will only be
considered to be in the Initial Population if they have an appropriate
continuous enrollment in that kind of medical plan.
If instead a null argument is given, their enrollment status will have no
effect on whether they are considered to be in the Initial Population.
If instead some other argument is given (an unrecognized plan type),
the patient will unconditionally NOT be in the Initial Population.
*/

parameter "Product Line" String
//parameter "Age Low" Integer
//parameter "Age High" Integer
//parameter "Fill Threshold" Integer
//parameter "Targeting Frequency" String

/*
This library has an explicit parameter which is the measurement year.
While the actual parameter's type accepts all intervals, this library
expects it will only be given arguments corresponding exactly to one whole
calendar year, and it will not behave properly otherwise; 2017 for example:
Interval[DateTime(2017,1,1,0,0,0,0), DateTime(2018,1,1,0,0,0,0))
*/

parameter "Measurement Period" Interval<DateTime>

/*
This library evaluates with respect to exactly 1 candidate patient at a time,
that patient being given by the special context parameter Patient.
*/

context Patient

define "StartDate":
	start of "Measurement Period"
  
define "EndDate":
	end of "Measurement Period"
  
define "AnchorDate":
	end of "Measurement Period"

define "Fill Threshold":
    end of "Measurement Period" - 90 days
    
define "Measurement Period Days":
    difference in days between start of "Measurement Period" and end of "Measurement Period"

/*
Initial Population: Age 65 at START of Measurement period
*/

define "Initial Population":
  "Is Between 40 and 75 At First Diabetes Med Fill"
    and ("Is Count of Distinct Diabetes Fill Dates greater than or equal to Two" is true)
    and "Is First Diabetes Fill Date in Measurement Period before day of Fill Threshold"

define "Is Between 40 and 75 At First Diabetes Med Fill":
  Common.CalendarAgeInYearsAt(FHIRHelpers.ToDate(Patient.birthDate), "First Diabetes Fill Date in Measurement Period") between 40 and 75

define "Is Count of Distinct Diabetes Fill Dates greater than or equal to Two":
    Count(Distinct("Diabetes Fill Dates in Measurement Period")) >=2

define "Is First Diabetes Fill Date in Measurement Period before day of Fill Threshold":
    "First Diabetes Fill Date in Measurement Period" before day of "Fill Threshold"
/*
JOIN METHOD:
    (
        from 
            [Medication: "DIABETES_MEDICATIONS"] M,
            [MedicationRequest] MR,
            [MedicationDispense] MD
            where MD.whenHandedOver in day of "Measurement Period"
                and MD.authorizingPrescription.reference = ('MedicationRequest/' + MR.id)
                and (MR.medication.reference) = ('Medication/' + M.id)
            sort by whenHandedOver
        ) 
*/  

//Dispensed medications for diabetes:
define "Diabetes Medication":
  [MedicationRequest] MR
    with [Medication: "DIABETES_MEDICATIONS"] M
      such that (MR.medication.reference) = ('Medication/' + M.id)

define "Diabetes Medication Dispensed":
    /*Find dispensed Diabetes medications during the meas period.*/
      [MedicationDispense] MD
        with "Diabetes Medication" MR
          such that MD.authorizingPrescription.reference = ('MedicationRequest/' + MR.id)
        where MD.whenHandedOver in day of "Measurement Period"

//Pharmacy claim meds:
define "Diabetes Medication Claim":
    (
        [Claim] DClaim
            where exists (
                DClaim.item DCItem
                where DCItem.productOrService in "DIABETES_MEDICATIONS"
                    and FHIRHelpers.ToDate(DCItem.serviced) in day of "Measurement Period"
                )
        )

define "Diabetes Dispensed Dates":
    ("Diabetes Medication Dispensed") 
      DMD
        return all DMD.whenHandedOver

define "Diabetes Claim Dates":
    ("Diabetes Medication Claim") 
      DCD
        return all FHIRHelpers.ToDate(DCD.item.serviced)

define "Diabetes Fill Dates in Measurement Period":
    (
      "Diabetes Claim Dates"
      union
      "Diabetes Dispensed Dates"
    )
    CombinedDF 
    return CombinedDF sort by value

define "First Diabetes Fill Date in Measurement Period":
    (
      First( "Diabetes Fill Dates in Measurement Period" )
    ) FF
    return FF.value

/*
Denominator Exclusions: Hospice stay, ESRD, Rhabdomyolysis or Myopathy, Pregnancy, Lactation, or Fertility,
Liver Disease, Pre-diabetes, PCOS.
*/

define "Denominator Exclusions":
    ("Does patient have DateOfDeath" is true)
        or Common."Has Hospice"
        or Common."Has ESRD"
        or "Has Rhabdomyolysis or Myopathy during the Measurement Period"
        or "Pregnancy in Measurement Period" 
        or "Has Liver Disease during the Measurement Period" 
        or "Has Prediabetes during the Measurement Period"
        or "Has PCOS during the Measurement Period"
  
define "Does patient have DateOfDeath":
  exists([Patient] patientDOD
         where 
            (
              patientDOD.deceased before day of end of "Measurement Period"
            )
        ) 

//Rhabdomyolysis or Myopathy within the Measurement Period
define "Has Rhabdomyolysis or Myopathy during the Measurement Period":
  (exists("Rhabdomyolysis or Myopathy Diagnosis")
          or exists("Rhabdomyolysis or Myopathy Claim")
        )

define "Rhabdomyolysis or Myopathy Diagnosis":
  (
    ["Condition": "RHABDOMYOLYSIS_MYOPATHY"] ROM
      where ROM.onset during day of "Measurement Period"
        or ROM.abatement during day of "Measurement Period"
          )

define "Rhabdomyolysis or Myopathy Claim":
  (
      [Claim] ClaimDiagnosisROM
          where exists (
            ClaimDiagnosisROM.diagnosis.diagnosis diagnosisCode
                where diagnosisCode in "RHABDOMYOLYSIS_MYOPATHY"
                    )
                      and exists (
                      ClaimDiagnosisROM.item diagnosisItem
                        where FHIRHelpers.ToDate(diagnosisItem.serviced) in day of "Measurement Period"
                            )
  )

//Pregnancy within the Measurement Period
define "Pregnancy in Measurement Period":
  (Patient.gender = 'female' or Patient.gender = 'F')
    and (
          exists("Pregnancy Diagnosis")
            or exists("Pregnancy Claim")
        )

define "Pregnancy Diagnosis":
  (
    ["Condition": "PREGNANCY"] Pregnancy
      where Pregnancy.onset during day of "Measurement Period"
        or Pregnancy.abatement during day of "Measurement Period"
          )

//
define "Pregnancy Claim":
  (
      [Claim] ClaimDiagnosisPreg
          where exists (
            ClaimDiagnosisPreg.diagnosis.diagnosis diagnosisCode
                where diagnosisCode in "PREGNANCY"
                    )
                      and exists (
                      ClaimDiagnosisPreg.item diagnosisItem
                        where FHIRHelpers.ToDate(diagnosisItem.serviced) in day of "Measurement Period"
                            )
  )

//Liver Disease within the Measurement Period
define "Has Liver Disease during the Measurement Period":
  (exists("Liver Disease Diagnosis")
          or exists("Liver Disease Claim")
        )

define "Liver Disease Diagnosis":
  (
    ["Condition": "LIVER_DISEASE"] LD
      where LD.onset during day of "Measurement Period"
        or LD.abatement during day of "Measurement Period"
          )

define "Liver Disease Claim":
  (
      [Claim] ClaimDiagnosisLD
          where exists (
            ClaimDiagnosisLD.diagnosis.diagnosis diagnosisCode
                where diagnosisCode in "LIVER_DISEASE"
                    )
                      and exists (
                      ClaimDiagnosisLD.item diagnosisItem
                        where FHIRHelpers.ToDate(diagnosisItem.serviced) in day of "Measurement Period"
                            )
  )

//Prediabetes within the Measurement Period
define "Has Prediabetes during the Measurement Period":
  (exists("Prediabetes Diagnosis")
          or exists("Prediabetes Claim")
        )

define "Prediabetes Diagnosis":
  (
    ["Condition": "PREDIABETES"] PD
      where PD.onset during day of "Measurement Period"
        or PD.abatement during day of "Measurement Period"
          )

define "Prediabetes Claim":
  (
      [Claim] ClaimDiagnosisPD
          where exists (
            ClaimDiagnosisPD.diagnosis.diagnosis diagnosisCode
                where diagnosisCode in "PREDIABETES"
                    )
                      and exists (
                      ClaimDiagnosisPD.item diagnosisItem
                        where FHIRHelpers.ToDate(diagnosisItem.serviced) in day of "Measurement Period"
                            )
  )

//PCOS within the Measurement Period
define "Has PCOS during the Measurement Period":
  (exists("PCOS Diagnosis")
          or exists("PCOS Claim")
        )

define "PCOS Diagnosis":
  (
    ["Condition": "PCOS"] PCOS
      where PCOS.onset during day of "Measurement Period"
        or PCOS.abatement during day of "Measurement Period"
          )

define "PCOS Claim":
  (
      [Claim] ClaimDiagnosisPCOS
          where exists (
            ClaimDiagnosisPCOS.diagnosis.diagnosis diagnosisCode
                where diagnosisCode in "PCOS"
                    )
                      and exists (
                      ClaimDiagnosisPCOS.item diagnosisItem
                        where FHIRHelpers.ToDate(diagnosisItem.serviced) in day of "Measurement Period"
                            )
  )

/*
Denominator: equal to Initial Patient Population
*/

define "Denominator":
  "Initial Population"
    and not("Denominator Exclusions" is true)
    
/*
Numerator: Patient does NOT have Statin fill within the period
*/

define "Numerator":
  "Denominator"
    and not exists("Statin Fill Dates in Measurement Period")


//Dispensed statins:
define "Statin Medication":
  [MedicationRequest] MR
    with [Medication: "STATINS"] M
      such that (MR.medication.reference) = ('Medication/' + M.id)

define "Statin Medication Dispensed":
    /*Find dispensed Diabetes medications during the meas period.*/
      [MedicationDispense] MD
        with "Statin Medication" MR
          such that MD.authorizingPrescription.reference = ('MedicationRequest/' + MR.id)
        where MD.whenHandedOver in day of "Measurement Period"

//Pharmacy claim meds:
define "Statin Medication Claim":
    (
        [Claim] DClaim
            where exists (
                DClaim.item DCItem
                where DCItem.productOrService in "STATINS"
                    and FHIRHelpers.ToDate(DCItem.serviced) in day of "Measurement Period"
                )
        )

define "Statin Dispensed Dates":
    ("Statin Medication Dispensed") 
      SDD
        return all SDD.whenHandedOver

define "Statin Claim Dates":
    ("Statin Medication Claim") 
      SMC
        return all FHIRHelpers.ToDate(SMC.item.serviced)

define "Statin Fill Dates in Measurement Period":
      "Statin Claim Dates"
        union "Statin Dispensed Dates"

/*
Most recent prescribing clinician based on diabetes fills:


define "Latest Diabetes Medication Dispensed":
  First(
        "Diabetes Medication Dispensed" LDM
          sort by whenHandedOver desc
        )

define "Latest Diabetes Medication Request":
    "Diabetes Medication" MRR
      with "Latest Diabetes Medication Dispensed" LDD
          such that LDD.authorizingPrescription.reference = ('MedicationRequest/' + MRR.id)

define "Diabetes Medication Prescriber":
  [Practitioner] PR
    with "Latest Diabetes Medication Request" LDMR
      such that (LDMR.requester.reference) = ('Practitioner/' + PR.id)
  
define "Diabetes Medication Prescriber Telecom":
  ("Diabetes Medication Prescriber") 
        TEL
          return all TEL.telecom
*/


define "Identified Practitioner":
  /*Find the Practitioner identified as the Patient's Primary Care Provider.*/
      [Practitioner] PR
        with [Patient] P 
          such that P.generalPractitioner.reference = ('Practitioner/' + PR.id)

define "Practitioner Telecom":
  (First("Identified Practitioner"))
        TEL
          return all TEL.telecom

//Encounter, Assessment and Opportunity Inserts

define "Program Type":
  'Algorithms'

define "Target":
  'Targeting'

define "Outcome":
  'AutofaxTMR'

define "Measure":
  'SUPD'

define "Encounter":
  'Gap in Care: Statin use in Diabetes or ASCVD'

define "MedReviewType":
  'GICS'

define "Task Description":
  'Gap in Care: Statin Use in Diabetes or ASCVD'

define "Assessment":
  'Gap in Care: Statin Use in Diabetes or ASCVD'

define "AssessmentNote":
  'Gap in Care: Statin Use in Diabetes or ASCVD Note'

define "PCP ProviderId":
  (First("Identified Practitioner"))."id"."value"

define "PCP Name":
  First((First("Identified Practitioner"))."name"."family")."value"  
  + ' ' +
  First((First("Identified Practitioner"))."name"."given")."value"  

define "PCP First Name":
  First((First("Identified Practitioner"))."name"."given")."value"  

define "PCP Last Name":
  First((First("Identified Practitioner"))."name"."family")."value"  

define "PCP Fax":
  First(("Practitioner Telecom") FXX
    where FXX.system = 'fax').value.value

/*
define "PCP ProviderId":
  ("Diabetes Medication Prescriber")."id"

define "PCP Name":
  ("Diabetes Medication Prescriber")."name"

define "PCP Fax":
  (First("Diabetes Medication Prescriber Telecom")) FXX
    where FXX.system = 'fax'
*/

//No medication passed for SUPD
define "Most Recent Medication Name String":
  ''

/*NO TRIGGER MED IN SUPD

define "Code for Trigger Medication if Needed": 
    First(
        (
            "Fills for Diabetes medication"
        ) P
        sort by id 
    )
*/

//NO OPPORTUNITY IN SUPD
define "Opportunity":
  ''

define "Opportunity Note":
  ''

//Payer: need to decide default enrollment criteria
define "Payer":
  (
    (["Coverage"]) P
    where  
        (
          end of P.period is null
            or
          P.period overlaps day of "Measurement Period"
        )
  )."type"."coding"."code"
  
  