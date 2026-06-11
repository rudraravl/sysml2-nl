package AutoclaveTapeSystemModel {

    import ScalarValues::*;
    import SI::*;

    attribute def Temperature : Real {
        unit = "degC";
    }

    attribute def Pressure : Real {
        unit = "kPa";
    }

    attribute def Duration : Real {
        unit = "min";
    }

    attribute def Humidity : Real {
        unit = "%RH";
    }

    attribute def ColorContrast : Real {
        unit = "deltaE";
    }

    attribute def AdhesionStrength : Real {
        unit = "N_per_25mm";
    }

    attribute def TapeLength : Real {
        unit = "m";
    }

    attribute def TapeWidth : Real {
        unit = "mm";
    }

    item def Steam {
        attribute temperature : Temperature;
        attribute pressure : Pressure;
        attribute relativeHumidity : Humidity;
    }

    item def SterilizationExposure {
        attribute exposureTemperature : Temperature;
        attribute exposurePressure : Pressure;
        attribute exposureDuration : Duration;
        attribute steamSaturation : Humidity;
    }

    item def VisualSignal {
        attribute contrast : ColorContrast;
        attribute observedState : IndicatorStateKind;
    }

    enum def IndicatorStateKind {
        enum unexposed;
        enum insufficientExposure;
        enum exposed;
        enum invalid;
    }

    enum def AdhesionStateKind {
        enum secured;
        enum lifting;
        enum detached;
    }

    port def SteamExposurePort {
        in item steam : Steam;
    }

    port def SurfaceAttachmentPort {
        out item attachmentState : AdhesionStateKind;
    }

    port def VisualIndicationPort {
        out item signal : VisualSignal;
    }

    port def OperatorObservationPort {
        in item observation : VisualSignal;
    }

    action def SenseAutoclaveExposure {
        in item incomingSteam : Steam;
        out item exposure : SterilizationExposure;

        attribute sampledTemperature : Temperature;
        attribute sampledPressure : Pressure;
        attribute accumulatedDuration : Duration;
        attribute sampledHumidity : Humidity;
    }

    action def ReactIndicatorInk {
        in item exposure : SterilizationExposure;
        out item signal : VisualSignal;

        attribute activationTemperature : Temperature = 121.0;
        attribute minimumDurationAt121C : Duration = 15.0;
        attribute minimumDurationAt134C : Duration = 3.0;
        attribute minimumSteamSaturation : Humidity = 95.0;
        attribute requiredContrast : ColorContrast = 15.0;
    }

    action def MaintainPackageClosure {
        in item exposure : SterilizationExposure;
        out item adhesionState : AdhesionStateKind;

        attribute minimumAdhesionAfterCycle : AdhesionStrength = 2.0;
    }

    action def InterpretTapeSignal {
        in item observedSignal : VisualSignal;
        out item acceptedForFurtherProcessing : Boolean;
    }

    state def TapeLifecycle {
        entry action initializeTape;

        state unused;
        state appliedToPackage;
        state inAutoclaveCycle;
        state indicatorChanging;
        state exposureIndicated;
        state insufficientExposureIndicated;
        state removedAfterUse;

        transition first unused then appliedToPackage
            accept ApplyTape;

        transition appliedToPackage then inAutoclaveCycle
            accept BeginCycle;

        transition inAutoclaveCycle then indicatorChanging
            accept SteamDetected
            if steam.temperature >= 121.0 and steam.relativeHumidity >= 95.0;

        transition indicatorChanging then exposureIndicated
            accept ExposureComplete
            if exposure.exposureTemperature >= 121.0 and exposure.exposureDuration >= 15.0;

        transition indicatorChanging then exposureIndicated
            accept FlashExposureComplete
            if exposure.exposureTemperature >= 134.0 and exposure.exposureDuration >= 3.0;

        transition indicatorChanging then insufficientExposureIndicated
            accept CycleEnded
            if signal.contrast < 15.0;

        transition exposureIndicated then removedAfterUse
            accept RemoveTape;

        transition insufficientExposureIndicated then removedAfterUse
            accept RemoveTape;
    }

    part def IndicatorStripe {
        attribute initialColor : String = "light beige";
        attribute exposedColor : String = "dark diagonal";
        attribute transitionContrast : ColorContrast;
        attribute state : IndicatorStateKind = IndicatorStateKind::unexposed;

        port steamIn : SteamExposurePort;
        port visualOut : VisualIndicationPort;

        perform action react : ReactIndicatorInk {
            in exposure;
            out signal;
        }
    }

    part def AdhesiveLayer {
        attribute nominalAdhesion : AdhesionStrength = 6.0;
        attribute postCycleAdhesion : AdhesionStrength;
        attribute state : AdhesionStateKind = AdhesionStateKind::secured;

        port attachmentOut : SurfaceAttachmentPort;

        perform action retainClosure : MaintainPackageClosure {
            in exposure;
            out adhesionState;
        }
    }

    part def CrepePaperBacking {
        attribute width : TapeWidth = 19.0;
        attribute rollLength : TapeLength = 55.0;
        attribute porousToSteam : Boolean = true;
        attribute tearableByHand : Boolean = true;
    }

    part def SterilizationPackage {
        attribute packageIdentifier : String;
        attribute sealed : Boolean;
        attribute externalSurfaceTemperature : Temperature;

        port packageSurface : SurfaceAttachmentPort;
    }

    part def AutoclaveChamber {
        attribute chamberTemperature : Temperature;
        attribute chamberPressure : Pressure;
        attribute cycleDuration : Duration;
        attribute steamHumidity : Humidity;

        port steamOut : SteamExposurePort;

        action generateSteamExposure : SenseAutoclaveExposure {
            in incomingSteam;
            out exposure;
        }
    }

    part def Operator {
        attribute trainedToReadTape : Boolean = true;

        port observationIn : OperatorObservationPort;

        perform action readIndicator : InterpretTapeSignal {
            in observedSignal;
            out acceptedForFurtherProcessing;
        }
    }

    part def AutoclaveTape {
        attribute tapeWidth : TapeWidth = 19.0;
        attribute remainingLength : TapeLength;
        attribute appliedLength : TapeLength;
        attribute requiredColorContrast : ColorContrast = 15.0;
        attribute primaryFunction : String =
            "Provide an external visual process indicator that a wrapped item has been exposed to steam autoclave conditions while also helping secure the package closure.";

        part backing : CrepePaperBacking;
        part adhesive : AdhesiveLayer;
        part stripe[3] : IndicatorStripe;

        port steamExposure : SteamExposurePort;
        port attachment : SurfaceAttachmentPort;
        port indication : VisualIndicationPort;

        connection steamToStripe1 connect steamExposure.steam to stripe[0].steamIn.steam;
        connection steamToStripe2 connect steamExposure.steam to stripe[1].steamIn.steam;
        connection steamToStripe3 connect steamExposure.steam to stripe[2].steamIn.steam;
        connection adhesionStatus connect adhesive.attachmentOut.attachmentState to attachment.attachmentState;
        connection stripeSignal connect stripe[0].visualOut.signal to indication.signal;

        exhibit state lifecycle : TapeLifecycle;
    }

    part def AutoclaveTapeUseSystem {
        part tape : AutoclaveTape;
        part package : SterilizationPackage {
            attribute packageIdentifier = "Wrapped surgical instrument tray";
            attribute sealed = true;
        }
        part autoclave : AutoclaveChamber {
            attribute chamberTemperature = 134.0;
            attribute chamberPressure = 210.0;
            attribute cycleDuration = 4.0;
            attribute steamHumidity = 98.0;
        }
        part operator : Operator;

        connection chamberSteamToTape connect autoclave.steamOut.steam to tape.steamExposure.steam;
        connection tapeAdheresToPackage connect tape.attachment.attachmentState to package.packageSurface.attachmentState;
        connection tapeObservedByOperator connect tape.indication.signal to operator.observationIn.observation;

        perform action exposureDetection : SenseAutoclaveExposure;
        perform action indicatorReaction : ReactIndicatorInk;
        perform action closureRetention : MaintainPackageClosure;
        perform action operatorInterpretation : InterpretTapeSignal;
    }

    requirement def PrimaryFunctionRequirement {
        doc
        /* The autoclave tape shall provide a high-level external indication that a package has been exposed to steam autoclave processing conditions. */
        subject tape : AutoclaveTape;

        require constraint {
            tape.primaryFunction != "";
        }
    }

    requirement def IndicatorActivationRequirement {
        doc
        /* The indicator stripes shall visibly change when exposed to saturated steam at 121 degC for at least 15 minutes or 134 degC for at least 3 minutes. */
        subject stripe : IndicatorStripe;

        require constraint {
            (exposure.exposureTemperature >= 121.0 and exposure.exposureDuration >= 15.0 and exposure.steamSaturation >= 95.0)
            or
            (exposure.exposureTemperature >= 134.0 and exposure.exposureDuration >= 3.0 and exposure.steamSaturation >= 95.0);
        }
    }

    requirement def VisualContrastRequirement {
        doc
        /* After successful exposure, the changed indicator shall provide sufficient contrast for unaided visual inspection. */
        subject signal : VisualSignal;

        require constraint {
            signal.contrast >= 15.0 and signal.observedState == IndicatorStateKind::exposed;
        }
    }

    requirement def AdhesionRequirement {
        doc
        /* The tape shall remain attached to the package through the autoclave cycle without detaching under normal handling. */
        subject adhesive : AdhesiveLayer;

        require constraint {
            adhesive.postCycleAdhesion >= 2.0 and adhesive.state != AdhesionStateKind::detached;
        }
    }

    requirement def NonSterilityClaimRequirement {
        doc
        /* The tape indication shall not be interpreted as proof that package contents are sterile; it only indicates external exposure to process conditions. */
        subject tape : AutoclaveTape;

        require constraint {
            tape.requiredColorContrast >= 15.0;
        }
    }

    satisfy PrimaryFunctionRequirement by AutoclaveTapeUseSystem::tape;
    satisfy IndicatorActivationRequirement by AutoclaveTape::stripe;
    satisfy VisualContrastRequirement by AutoclaveTape::indication;
    satisfy AdhesionRequirement by AutoclaveTape::adhesive;
    satisfy NonSterilityClaimRequirement by AutoclaveTapeUseSystem::tape;
}