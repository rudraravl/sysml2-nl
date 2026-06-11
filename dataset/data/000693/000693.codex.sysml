package MicroneedleTherapeuticPatchModel {

    import ScalarValues::*;
    import SI::*;

    value def Micrometer :> LengthUnit;
    value def Millimeter :> LengthUnit;
    value def SquareCentimeter :> AreaUnit;
    value def Milligram :> MassUnit;
    value def Microgram :> MassUnit;
    value def Microliter :> VolumeUnit;
    value def Minute :> TimeUnit;
    value def Hour :> TimeUnit;
    value def Kilopascal :> PressureUnit;
    value def DegreeCelsius :> TemperatureUnit;

    item def TherapeuticAgent {
        attribute agentName : String;
        attribute formulationMass : Real [Milligram];
        attribute activeDose : Real [Microgram];
        attribute concentration : Real;
        attribute storageTemperatureMin : Real [DegreeCelsius];
        attribute storageTemperatureMax : Real [DegreeCelsius];
    }

    item def InterstitialFluid {
        attribute sampledVolume : Real [Microliter];
        attribute glucoseConcentration : Real;
        attribute biomarkerConcentration : Real;
    }

    item def SkinContactStatus {
        attribute contactEstablished : Boolean;
        attribute insertionDepth : Real [Micrometer];
        attribute contactPressure : Real [Kilopascal];
        attribute leakDetected : Boolean;
    }

    item def DoseDeliveryStatus {
        attribute deliveredDose : Real [Microgram];
        attribute remainingDose : Real [Microgram];
        attribute deliveryComplete : Boolean;
        attribute estimatedCompletionTime : Real [Minute];
    }

    item def UserCommand {
        attribute startDelivery : Boolean;
        attribute stopDelivery : Boolean;
        attribute requestStatus : Boolean;
    }

    item def PatchTelemetry {
        attribute adhesionValid : Boolean;
        attribute reservoirLevel : Real [Microliter];
        attribute deliveredDose : Real [Microgram];
        attribute faultActive : Boolean;
        attribute stateName : String;
    }

    port def DrugOutletPort {
        out item therapeuticAgent : TherapeuticAgent;
    }

    port def SkinInterfacePort {
        out item therapeuticAgent : TherapeuticAgent;
        in item interstitialFluid : InterstitialFluid;
        out item contactStatus : SkinContactStatus;
    }

    port def CommandPort {
        in item command : UserCommand;
    }

    port def TelemetryPort {
        out item telemetry : PatchTelemetry;
    }

    port def FluidPort {
        in item therapeuticAgent : TherapeuticAgent;
        out item deliveryStatus : DoseDeliveryStatus;
    }

    part def MicroneedleArray {
        attribute needleCount : Integer;
        attribute needleLength : Real [Micrometer];
        attribute needleBaseWidth : Real [Micrometer];
        attribute needleTipRadius : Real [Micrometer];
        attribute arrayArea : Real [SquareCentimeter];
        attribute insertionForcePerNeedle : Real;
        attribute biocompatible : Boolean;

        port skinInterface : SkinInterfacePort;

        action insertIntoSkin {
            in item commandedContact : SkinContactStatus;
            out item achievedContact : SkinContactStatus;

            first start;
            then verifyNeedleGeometry;
            then penetrateStratumCorneum;
            then reportContact;

            action verifyNeedleGeometry;
            action penetrateStratumCorneum;
            action reportContact;
        }

        action releaseTherapeuticAgent {
            in item agent : TherapeuticAgent;
            out item status : DoseDeliveryStatus;

            first receiveAgent;
            then distributeAcrossNeedles;
            then diffuseIntoInterstitialSpace;
            then estimateDose;

            action receiveAgent;
            action distributeAcrossNeedles;
            action diffuseIntoInterstitialSpace;
            action estimateDose;
        }
    }

    part def DrugReservoir {
        attribute reservoirCapacity : Real [Microliter];
        attribute initialFillVolume : Real [Microliter];
        attribute currentVolume : Real [Microliter];
        attribute maxDose : Real [Microgram];
        attribute agentStabilityHours : Real [Hour];

        port outlet : FluidPort;

        action meterDose {
            in item command : UserCommand;
            out item agent : TherapeuticAgent;
            out item status : DoseDeliveryStatus;

            first validateCommand;
            then calculateMeteredVolume;
            then releaseMeteredDose;
            then updateRemainingVolume;

            action validateCommand;
            action calculateMeteredVolume;
            action releaseMeteredDose;
            action updateRemainingVolume;
        }
    }

    part def AdhesiveBacking {
        attribute contactArea : Real [SquareCentimeter];
        attribute peelStrength : Real;
        attribute wearDuration : Real [Hour];
        attribute hypoallergenic : Boolean;

        action maintainSkinContact {
            in item contactStatus : SkinContactStatus;
            out item adhesionValid : Boolean;

            first senseContactPressure;
            then evaluateAdhesion;
            then reportAdhesion;

            action senseContactPressure;
            action evaluateAdhesion;
            action reportAdhesion;
        }
    }

    part def DoseController {
        attribute prescribedDose : Real [Microgram];
        attribute doseRate : Real;
        attribute maxDeliveryDuration : Real [Minute];
        attribute closedLoopEnabled : Boolean;

        port commandIn : CommandPort;
        port telemetryOut : TelemetryPort;

        action controlDelivery {
            in item command : UserCommand;
            in item contactStatus : SkinContactStatus;
            in item reservoirStatus : DoseDeliveryStatus;
            out item telemetry : PatchTelemetry;

            first interpretCommand;
            then checkSafetyInterlocks;
            then commandReservoir;
            then updateTelemetry;

            action interpretCommand;
            action checkSafetyInterlocks;
            action commandReservoir;
            action updateTelemetry;
        }
    }

    part def Biosensor {
        attribute samplingInterval : Real [Minute];
        attribute minimumSampleVolume : Real [Microliter];
        attribute measurementAccuracy : Real;
        attribute enabled : Boolean;

        port skinInterface : SkinInterfacePort;

        action sampleInterstitialFluid {
            out item sample : InterstitialFluid;

            first drawMicroSample;
            then measureBiomarker;
            then publishMeasurement;

            action drawMicroSample;
            action measureBiomarker;
            action publishMeasurement;
        }
    }

    part def MicroneedlePatchSystem {
        attribute patchMass : Real [Milligram];
        attribute patchThickness : Real [Millimeter];
        attribute intendedWearTime : Real [Hour];
        attribute primaryFunction : String = "Deliver a controlled therapeutic dose across the outer skin barrier using minimally invasive microneedles.";

        part microneedleArray : MicroneedleArray {
            attribute needleCount = 361;
            attribute needleLength = 650 [Micrometer];
            attribute needleBaseWidth = 180 [Micrometer];
            attribute needleTipRadius = 5 [Micrometer];
            attribute arrayArea = 4.0 [SquareCentimeter];
            attribute biocompatible = true;
        }

        part reservoir : DrugReservoir {
            attribute reservoirCapacity = 250 [Microliter];
            attribute initialFillVolume = 200 [Microliter];
            attribute currentVolume = 200 [Microliter];
            attribute maxDose = 5000 [Microgram];
            attribute agentStabilityHours = 72 [Hour];
        }

        part adhesive : AdhesiveBacking {
            attribute contactArea = 12.0 [SquareCentimeter];
            attribute wearDuration = 24 [Hour];
            attribute hypoallergenic = true;
        }

        part controller : DoseController {
            attribute prescribedDose = 1200 [Microgram];
            attribute maxDeliveryDuration = 30 [Minute];
            attribute closedLoopEnabled = true;
        }

        part biosensor : Biosensor {
            attribute samplingInterval = 5 [Minute];
            attribute minimumSampleVolume = 0.25 [Microliter];
            attribute enabled = true;
        }

        port userCommand : CommandPort;
        port userTelemetry : TelemetryPort;
        port skinInterface : SkinInterfacePort;

        connect userCommand to controller.commandIn;
        connect controller.telemetryOut to userTelemetry;
        connect reservoir.outlet to microneedleArray.skinInterface;
        connect microneedleArray.skinInterface to skinInterface;
        connect biosensor.skinInterface to skinInterface;

        action performPrimaryFunction {
            in item command : UserCommand;
            out item telemetry : PatchTelemetry;

            first receiveUserCommand;
            then confirmPatchAdhesion;
            then insertMicroneedles;
            then meterTherapeuticAgent;
            then deliverDoseAcrossSkin;
            then monitorDoseAndSkinContact;
            then reportCompletionStatus;

            action receiveUserCommand;
            action confirmPatchAdhesion;
            action insertMicroneedles;
            action meterTherapeuticAgent;
            action deliverDoseAcrossSkin;
            action monitorDoseAndSkinContact;
            action reportCompletionStatus;
        }

        state def PatchOperationalState {
            state Off;
            state Ready;
            state Adhered;
            state Inserting;
            state Delivering;
            state Monitoring;
            state Complete;
            state Fault;

            transition initial then Off;
            transition Off to Ready;
            transition Ready to Adhered;
            transition Adhered to Inserting;
            transition Inserting to Delivering;
            transition Delivering to Monitoring;
            transition Monitoring to Complete;
            transition Ready to Fault;
            transition Adhered to Fault;
            transition Inserting to Fault;
            transition Delivering to Fault;
            transition Monitoring to Fault;
            transition Fault to Off;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject patch : MicroneedlePatchSystem;

        doc /* The microneedle patch shall provide minimally invasive transdermal delivery of a therapeutic agent by breaching the stratum corneum with a controlled microneedle array and transferring a prescribed dose from an integrated reservoir into the skin. */

        require constraint {
            patch.primaryFunction == "Deliver a controlled therapeutic dose across the outer skin barrier using minimally invasive microneedles."
        }
    }

    requirement def NeedleGeometryRequirement {
        subject array : MicroneedleArray;

        require constraint {
            array.needleLength >= 300 [Micrometer] and
            array.needleLength <= 900 [Micrometer] and
            array.needleTipRadius <= 10 [Micrometer]
        }
    }

    requirement def DoseCapacityRequirement {
        subject reservoir : DrugReservoir;

        require constraint {
            reservoir.reservoirCapacity >= 100 [Microliter] and
            reservoir.maxDose >= 1000 [Microgram]
        }
    }

    requirement def WearabilityRequirement {
        subject adhesive : AdhesiveBacking;

        require constraint {
            adhesive.wearDuration >= 8 [Hour] and
            adhesive.hypoallergenic == true
        }
    }

    requirement def DeliveryControlRequirement {
        subject controller : DoseController;

        require constraint {
            controller.prescribedDose > 0 [Microgram] and
            controller.maxDeliveryDuration <= 60 [Minute]
        }
    }

    requirement def SkinInterfaceSafetyRequirement {
        subject patch : MicroneedlePatchSystem;

        doc /* The system shall stop delivery and enter a fault state when loss of skin contact, excessive leakage, or invalid adhesion is detected during insertion or dosing. */
    }

    requirement def TelemetryRequirement {
        subject patch : MicroneedlePatchSystem;

        doc /* The system shall report adhesion status, reservoir level, delivered dose, operating state, and active fault indication to the user interface. */
    }

    satisfy PrimaryFunctionRequirement by MicroneedlePatchSystem;
    satisfy NeedleGeometryRequirement by MicroneedleArray;
    satisfy DoseCapacityRequirement by DrugReservoir;
    satisfy WearabilityRequirement by AdhesiveBacking;
    satisfy DeliveryControlRequirement by DoseController;
    satisfy SkinInterfaceSafetyRequirement by MicroneedlePatchSystem;
    satisfy TelemetryRequirement by MicroneedlePatchSystem;
}