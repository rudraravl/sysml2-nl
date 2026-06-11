package MedicalIdentificationTagModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def TextString;
    attribute def Identifier;
    attribute def DateTime;
    attribute def BooleanFlag;
    attribute def URLString;
    attribute def PhoneNumber;
    attribute def BloodGroup;
    attribute def MedicalConditionName;
    attribute def MedicationName;
    attribute def AllergyName;
    attribute def EmergencyInstruction;

    enum def TagOperationalState {
        enum idle;
        enum beingRead;
        enum emergencyInformationDisplayed;
        enum updatePending;
        enum disabled;
    }

    enum def AlertPriority {
        enum routine;
        enum urgent;
        enum critical;
    }

    enum def ContactRole {
        enum family;
        enum physician;
        enum caregiver;
        enum emergencyService;
    }

    enum def AccessMode {
        enum visualRead;
        enum nfcRead;
        enum qrRead;
    }

    item def EmergencyResponder {
        attribute responderId : Identifier;
        attribute organization : TextString;
    }

    item def TagOwner {
        attribute ownerId : Identifier;
        attribute fullName : TextString;
        attribute dateOfBirth : DateTime;
        attribute preferredLanguage : TextString;
    }

    item def MedicalProfile {
        attribute ownerName : TextString;
        attribute bloodType : BloodGroup;
        attribute majorConditions : MedicalConditionName[0..*];
        attribute allergies : AllergyName[0..*];
        attribute medications : MedicationName[0..*];
        attribute implantedDevices : TextString[0..*];
        attribute emergencyInstructions : EmergencyInstruction[1..*];
        attribute lastVerified : DateTime;
    }

    item def EmergencyContactInfo {
        attribute contactName : TextString;
        attribute role : ContactRole;
        attribute phone : PhoneNumber;
        attribute alternatePhone : PhoneNumber;
        attribute available24Hours : BooleanFlag;
    }

    item def PublicEmergencySummary {
        attribute displayedName : TextString;
        attribute bloodType : BloodGroup;
        attribute criticalAllergies : AllergyName[0..*];
        attribute criticalConditions : MedicalConditionName[0..*];
        attribute primaryMedicationWarnings : MedicationName[0..*];
        attribute emergencyInstructionText : EmergencyInstruction[1..*];
        attribute contactPhone : PhoneNumber;
        attribute profileVerificationTime : DateTime;
    }

    item def AccessEvent {
        attribute eventTime : DateTime;
        attribute accessMode : AccessMode;
        attribute readerDescription : TextString;
        attribute successful : BooleanFlag;
    }

    item def PowerStatus {
        attribute batteryCharge : Real;
        attribute lowPower : BooleanFlag;
    }

    item def TagUpdatePackage {
        attribute packageId : Identifier;
        attribute issuedTime : DateTime;
        attribute profile : MedicalProfile;
        attribute contact : EmergencyContactInfo;
        attribute signatureValid : BooleanFlag;
    }

    port def VisualInformationPort {
        out item summary : PublicEmergencySummary;
        out item printedIdentifier : Identifier;
    }

    port def WirelessReadPort {
        out item summary : PublicEmergencySummary;
        in item readRequest : AccessEvent;
    }

    port def UpdatePort {
        in item updatePackage : TagUpdatePackage;
        out item updateResult : BooleanFlag;
    }

    port def OwnerAssociationPort {
        in item owner : TagOwner;
        out item profile : MedicalProfile;
    }

    port def AuditPort {
        out item accessEvent : AccessEvent;
    }

    part def MedicalIdentificationTag {
        attribute tagSerialNumber : Identifier;
        attribute profileUrl : URLString;
        attribute isWaterResistant : BooleanFlag = true;
        attribute maximumReadableDistance : LengthValue = 0.04 [m];
        attribute nominalMass : MassValue = 0.018 [kg];
        attribute operatingTemperatureMinimum : TemperatureValue = 253.15 [K];
        attribute operatingTemperatureMaximum : TemperatureValue = 333.15 [K];

        port visualPort : VisualInformationPort;
        port nfcPort : WirelessReadPort;
        port qrPort : VisualInformationPort;
        port maintenancePort : UpdatePort;
        port ownerPort : OwnerAssociationPort;
        port auditPort : AuditPort;

        part substrate {
            attribute material : TextString = "engraved stainless steel with polymer inlay";
            attribute thickness : LengthValue = 0.0016 [m];
            attribute width : LengthValue = 0.028 [m];
            attribute height : LengthValue = 0.050 [m];
            attribute corrosionResistant : BooleanFlag = true;
        }

        part engravedFaceplate {
            attribute visibleOwnerName : TextString;
            attribute visibleCriticalWarning : EmergencyInstruction;
            attribute engravedBloodType : BloodGroup;
            attribute engravedEmergencyPhone : PhoneNumber;
            port faceDisplay : VisualInformationPort;
        }

        part qrCodeLabel {
            attribute encodedProfileUrl : URLString;
            attribute errorCorrectionLevel : TextString = "Q";
            attribute minimumModuleSize : LengthValue = 0.00035 [m];
            port opticalReadout : VisualInformationPort;
        }

        part nfcModule {
            attribute memoryCapacity : Integer = 2048;
            attribute frequency : FrequencyValue = 13560000 [Hz];
            attribute passivePowered : BooleanFlag = true;
            port radioReadout : WirelessReadPort;
        }

        part emergencyDataStore {
            attribute encryptedAtRest : BooleanFlag = true;
            attribute profileVersion : Identifier;
            attribute retainedAccessEvents : Integer = 50;
            item profile : MedicalProfile;
            item emergencyContact : EmergencyContactInfo;
            item emergencySummary : PublicEmergencySummary;
            item accessLog : AccessEvent[0..50];
        }

        part privacyController {
            attribute exposesOnlyEmergencyMinimum : BooleanFlag = true;
            attribute authenticationRequiredForUpdate : BooleanFlag = true;
            port updateInterface : UpdatePort;
            port auditInterface : AuditPort;
        }

        part powerIndicator {
            attribute batterylessNormalOperation : BooleanFlag = true;
            item status : PowerStatus;
        }

        connect engravedFaceplate.faceDisplay to visualPort;
        connect qrCodeLabel.opticalReadout to qrPort;
        connect nfcModule.radioReadout to nfcPort;
        connect privacyController.updateInterface to maintenancePort;
        connect privacyController.auditInterface to auditPort;

        perform action exposeEmergencySummary;
        perform action acceptProfileUpdate;
        perform action recordAccessEvent;

        state tagState : TagOperationalState {
            entry; then idle;

            state idle;
            state beingRead;
            state emergencyInformationDisplayed;
            state updatePending;
            state disabled;

            transition idle_to_beingRead
                first idle
                accept AccessEvent
                then beingRead;

            transition beingRead_to_displayed
                first beingRead
                if emergencyDataStore.emergencySummary.displayedName != ""
                then emergencyInformationDisplayed;

            transition displayed_to_idle
                first emergencyInformationDisplayed
                then idle;

            transition idle_to_updatePending
                first idle
                accept TagUpdatePackage
                then updatePending;

            transition updatePending_to_idle
                first updatePending
                if privacyController.authenticationRequiredForUpdate == true
                then idle;

            transition any_to_disabled
                first idle
                if emergencyDataStore.profileVersion == "REVOKED"
                then disabled;
        }
    }

    part def EmergencyMedicalIdentificationService {
        attribute serviceName : TextString = "Medical Identification Tag Emergency Information Service";
        attribute primaryFunction : TextString =
            "Provide immediately readable, concise, and reliable medical identity information so responders can identify the wearer, recognize critical conditions or allergies, and contact an emergency contact during urgent care.";

        port ownerEnrollment : OwnerAssociationPort;
        port tagUpdate : UpdatePort;
        port responderAccess : WirelessReadPort;
        port publicVisualAccess : VisualInformationPort;
        port auditOutput : AuditPort;

        part tag : MedicalIdentificationTag;
        part owner {
            item identity : TagOwner;
        }
        part responder {
            item responderIdentity : EmergencyResponder;
        }
        part profileRegistry {
            attribute recordRetentionPeriod : TimeValue = 31536000 [s];
            item storedProfile : MedicalProfile;
            item storedContact : EmergencyContactInfo;
        }
        part emergencyAccessPolicy {
            attribute allowUnauthenticatedEmergencyRead : BooleanFlag = true;
            attribute allowMedicationDetailRead : BooleanFlag = true;
            attribute allowFullAddressRead : BooleanFlag = false;
            attribute logWirelessReads : BooleanFlag = true;
        }

        connect ownerEnrollment to tag.ownerPort;
        connect tagUpdate to tag.maintenancePort;
        connect responderAccess to tag.nfcPort;
        connect publicVisualAccess to tag.visualPort;
        connect auditOutput to tag.auditPort;
    }

    action def ExposeEmergencySummary {
        in item request : AccessEvent;
        in item profile : MedicalProfile;
        in item contact : EmergencyContactInfo;
        out item summary : PublicEmergencySummary;

        first start;
        then composeMinimumEmergencyDataset;
        then publishToVisualAndWirelessPorts;
        then done;

        action composeMinimumEmergencyDataset {
            out item summary : PublicEmergencySummary;
        }

        action publishToVisualAndWirelessPorts {
            in item summary : PublicEmergencySummary;
        }
    }

    action def ValidateAndApplyProfileUpdate {
        in item updatePackage : TagUpdatePackage;
        out item accepted : BooleanFlag;

        first receiveUpdate;
        then verifyDigitalSignature;
        then checkProfileCompleteness;
        then writeEmergencyDataStore;
        then reportResult;

        action receiveUpdate;
        action verifyDigitalSignature;
        action checkProfileCompleteness;
        action writeEmergencyDataStore;
        action reportResult;
    }

    action def RecordAccessEvent {
        in item accessEvent : AccessEvent;
        out item retainedEvent : AccessEvent;

        first captureEvent;
        then classifyAccessMode;
        then storeRecentEvent;
        then emitAuditRecord;

        action captureEvent;
        action classifyAccessMode;
        action storeRecentEvent;
        action emitAuditRecord;
    }

    requirement def PrimaryFunctionRequirement {
        doc
            /* The medical identification tag shall make essential medical identity information available at the point of care during an emergency. */
        subject system : EmergencyMedicalIdentificationService;

        require constraint {
            system.primaryFunction != "";
        }
    }

    requirement def ImmediateReadabilityRequirement {
        doc
            /* The tag shall expose a public emergency summary through visible engraving, QR code, and NFC read access without requiring the wearer to speak or operate the device. */
        subject tag : MedicalIdentificationTag;

        require constraint {
            tag.isWaterResistant == true and
            tag.maximumReadableDistance <= 0.05 [m];
        }
    }

    requirement def CriticalInformationRequirement {
        doc
            /* The emergency summary shall include owner name, blood type, critical allergies, critical conditions, emergency instructions, and at least one contact phone number. */
        subject summary : PublicEmergencySummary;

        require constraint {
            summary.displayedName != "" and
            summary.bloodType != "" and
            summary.contactPhone != "";
        }
    }

    requirement def PrivacyRequirement {
        doc
            /* The tag shall limit unauthenticated access to information needed for emergency response and shall require authenticated update packages for changing stored data. */
        subject tag : MedicalIdentificationTag;

        require constraint {
            tag.privacyController.exposesOnlyEmergencyMinimum == true and
            tag.privacyController.authenticationRequiredForUpdate == true;
        }
    }

    requirement def DurabilityRequirement {
        doc
            /* The physical tag shall remain readable during normal daily wear, moisture exposure, and typical emergency handling. */
        subject tag : MedicalIdentificationTag;

        require constraint {
            tag.substrate.corrosionResistant == true and
            tag.substrate.thickness >= 0.001 [m] and
            tag.operatingTemperatureMinimum <= 273.15 [K] and
            tag.operatingTemperatureMaximum >= 313.15 [K];
        }
    }

    requirement def AuditRequirement {
        doc
            /* The system shall retain recent electronic access events to support owner review and security monitoring. */
        subject tag : MedicalIdentificationTag;

        require constraint {
            tag.emergencyDataStore.retainedAccessEvents >= 25;
        }
    }

    satisfy PrimaryFunctionRequirement by EmergencyMedicalIdentificationService;
    satisfy ImmediateReadabilityRequirement by MedicalIdentificationTag;
    satisfy PrivacyRequirement by MedicalIdentificationTag;
    satisfy DurabilityRequirement by MedicalIdentificationTag;
    satisfy AuditRequirement by MedicalIdentificationTag;

    analysis def EmergencyReadAnalysis {
        subject service : EmergencyMedicalIdentificationService;

        objective {
            doc
                /* Confirm that the service can provide enough high-level medical identification information for emergency triage without depending on active wearer participation. */
        }

        return item result : BooleanFlag;
    }

    package ExampleConfiguration {
        part emergencyTagSystem : EmergencyMedicalIdentificationService {
            attribute serviceName = "Wearable Medical ID Tag System";

            part tag {
                attribute tagSerialNumber = "MID-2026-000184";
                attribute profileUrl = "https://medical-id.example/profile/MID-2026-000184";

                part engravedFaceplate {
                    attribute visibleOwnerName = "Alex Morgan";
                    attribute visibleCriticalWarning = "Severe penicillin allergy; check NFC or QR for current medication list.";
                    attribute engravedBloodType = "O+";
                    attribute engravedEmergencyPhone = "+1-312-555-0184";
                }

                part emergencyDataStore {
                    attribute profileVersion = "v7";

                    item profile {
                        attribute ownerName = "Alex Morgan";
                        attribute bloodType = "O+";
                        attribute majorConditions = ("Type 1 diabetes", "history of anaphylaxis");
                        attribute allergies = ("penicillin", "bee venom");
                        attribute medications = ("insulin lispro", "glucagon rescue kit");
                        attribute implantedDevices = ("continuous glucose monitor");
                        attribute emergencyInstructions = (
                            "If unconscious, check glucose immediately.",
                            "Use glucagon rescue kit for severe hypoglycemia.",
                            "Avoid penicillin-class antibiotics."
                        );
                        attribute lastVerified = "2026-05-20T14:30:00-05:00";
                    }

                    item emergencyContact {
                        attribute contactName = "Jordan Morgan";
                        attribute role = family;
                        attribute phone = "+1-312-555-0184";
                        attribute alternatePhone = "+1-312-555-0190";
                        attribute available24Hours = true;
                    }

                    item emergencySummary {
                        attribute displayedName = "Alex Morgan";
                        attribute bloodType = "O+";
                        attribute criticalAllergies = ("penicillin", "bee venom");
                        attribute criticalConditions = ("Type 1 diabetes", "history of anaphylaxis");
                        attribute primaryMedicationWarnings = ("insulin lispro", "glucagon rescue kit");
                        attribute emergencyInstructionText = (
                            "Check glucose if altered or unconscious.",
                            "Avoid penicillin-class antibiotics.",
                            "Call emergency contact after stabilization."
                        );
                        attribute contactPhone = "+1-312-555-0184";
                        attribute profileVerificationTime = "2026-05-20T14:30:00-05:00";
                    }
                }
            }

            part profileRegistry {
                item storedProfile {
                    attribute ownerName = "Alex Morgan";
                    attribute bloodType = "O+";
                    attribute majorConditions = ("Type 1 diabetes", "history of anaphylaxis");
                    attribute allergies = ("penicillin", "bee venom");
                    attribute medications = ("insulin lispro", "glucagon rescue kit");
                    attribute implantedDevices = ("continuous glucose monitor");
                    attribute emergencyInstructions = (
                        "If unconscious, check glucose immediately.",
                        "Use glucagon rescue kit for severe hypoglycemia.",
                        "Avoid penicillin-class antibiotics."
                    );
                    attribute lastVerified = "2026-05-20T14:30:00-05:00";
                }

                item storedContact {
                    attribute contactName = "Jordan Morgan";
                    attribute role = family;
                    attribute phone = "+1-312-555-0184";
                    attribute alternatePhone = "+1-312-555-0190";
                    attribute available24Hours = true;
                }
            }
        }
    }
}