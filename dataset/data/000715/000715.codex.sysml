package OphthalmoscopySystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Illuminance :> ScalarValues::Real {
        unit = lx;
    }

    attribute def LuminousFlux :> ScalarValues::Real {
        unit = lm;
    }

    attribute def OpticalPower :> ScalarValues::Real {
        unit = mW;
    }

    attribute def Irradiance :> ScalarValues::Real {
        unit = mW / cm^2;
    }

    attribute def Diopter :> ScalarValues::Real {
        unit = 1 / m;
    }

    attribute def FieldOfViewAngle :> ScalarValues::Real {
        unit = deg;
    }

    attribute def FrameRate :> ScalarValues::Real {
        unit = Hz;
    }

    attribute def ImageResolution :> ScalarValues::Integer;

    attribute def TemperatureCelsius :> ScalarValues::Real {
        unit = degC;
    }

    attribute def BatteryCapacity :> ScalarValues::Real {
        unit = A * h;
    }

    attribute def ElectricVoltage :> ScalarValues::Real {
        unit = V;
    }

    attribute def ElectricCurrent :> ScalarValues::Real {
        unit = A;
    }

    enum def ExamMode {
        enum directViewing;
        enum digitalCapture;
        enum redFree;
        enum lowIllumination;
    }

    enum def FocusStatus {
        enum searching;
        enum focused;
        enum outOfRange;
    }

    enum def PatientEyeSide {
        enum leftEye;
        enum rightEye;
    }

    item def LightEnergy {
        attribute wavelength : ScalarValues::Real {
            unit = nm;
        }
        attribute opticalPower : OpticalPower;
        attribute irradianceAtCornea : Irradiance;
    }

    item def RetinalImage {
        attribute horizontalPixels : ImageResolution;
        attribute verticalPixels : ImageResolution;
        attribute fieldOfView : FieldOfViewAngle;
        attribute frameRate : FrameRate;
        attribute focusQuality : ScalarValues::Real;
        attribute eyeSide : PatientEyeSide;
    }

    item def ClinicalObservation {
        attribute opticDiscVisible : ScalarValues::Boolean;
        attribute maculaVisible : ScalarValues::Boolean;
        attribute vesselPatternVisible : ScalarValues::Boolean;
        attribute suspectedAbnormality : ScalarValues::Boolean;
        attribute note : ScalarValues::String;
    }

    item def ElectricalPower {
        attribute voltage : ElectricVoltage;
        attribute current : ElectricCurrent;
    }

    item def UserCommand {
        attribute requestedMode : ExamMode;
        attribute captureRequested : ScalarValues::Boolean;
        attribute illuminationStep : ScalarValues::Integer;
        attribute focusAdjustment : Diopter;
    }

    port def OpticalIlluminationPort {
        out item emittedLight : LightEnergy;
    }

    port def OpticalReturnPort {
        in item reflectedLight : LightEnergy;
    }

    port def ImageOutputPort {
        out item image : RetinalImage;
    }

    port def ObservationOutputPort {
        out item observation : ClinicalObservation;
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    port def PowerOutputPort {
        out item power : ElectricalPower;
    }

    port def CommandInputPort {
        in item command : UserCommand;
    }

    part def PatientEye {
        attribute eyeSide : PatientEyeSide;
        attribute pupilDiameter : ScalarValues::Real {
            unit = mm;
        }
        attribute refractiveError : Diopter;
        attribute retinalReflectance : ScalarValues::Real;

        port illuminationIn : OpticalReturnPort;
        port retinalReturnOut : OpticalIlluminationPort;

        action reflectFundusLight {
            in item incidentLight : LightEnergy;
            out item reflectedLight : LightEnergy;

            first start;
            then attenuateCornealAndLensTransmission;
            then scatterFromRetina;
            then outputRetinalReturn;
            then done;
        }
    }

    part def IlluminationSubsystem {
        attribute selectedMode : ExamMode;
        attribute ledWavelength : ScalarValues::Real {
            unit = nm;
        }
        attribute luminousFlux : LuminousFlux;
        attribute cornealIrradiance : Irradiance;
        attribute maxCornealIrradiance : Irradiance = 1.5 [mW / cm^2];

        port powerIn : PowerInputPort;
        port commandIn : CommandInputPort;
        port lightOut : OpticalIlluminationPort;

        action regulateIllumination {
            in item command : UserCommand;
            in item supply : ElectricalPower;
            out item emittedLight : LightEnergy;

            first receiveModeAndIntensity;
            then selectFilterForMode;
            then limitCornealIrradiance;
            then driveLightSource;
            then emitCoaxialLight;
            then done;
        }

        state illuminationState {
            entry; then off;

            state off;
            state standby;
            state illuminating;
            state safetyLimited;
            state fault;

            transition off_to_standby
                first off
                accept UserCommand
                if requestedMode != null
                then standby;

            transition standby_to_illuminating
                first standby
                accept UserCommand
                if illuminationStep > 0
                then illuminating;

            transition illuminating_to_safetyLimited
                first illuminating
                if cornealIrradiance > maxCornealIrradiance
                then safetyLimited;

            transition safetyLimited_to_illuminating
                first safetyLimited
                if cornealIrradiance <= maxCornealIrradiance
                then illuminating;

            transition any_to_fault
                first off
                if false
                then fault;
        }
    }

    part def OpticalTrain {
        attribute workingDistance : ScalarValues::Real {
            unit = mm;
        }
        attribute fieldOfView : FieldOfViewAngle;
        attribute focusRangeMin : Diopter = -20 [1 / m];
        attribute focusRangeMax : Diopter = 20 [1 / m];
        attribute currentFocus : Diopter;
        attribute focusStatus : FocusStatus;

        port illuminationIn : OpticalReturnPort;
        port returnIn : OpticalReturnPort;
        port imageLightOut : OpticalIlluminationPort;

        action focusRetinalImage {
            in item command : UserCommand;
            in item retinalReturn : LightEnergy;
            out item focusedReturn : LightEnergy;

            first receiveRetinalReturn;
            then adjustLensPower;
            then evaluateContrast;
            then stabilizeFocus;
            then outputFocusedOpticalImage;
            then done;
        }

        state focusingState {
            entry; then idle;

            state idle;
            state coarseSearch;
            state fineFocus;
            state locked;
            state outOfRange;

            transition idle_to_coarseSearch
                first idle
                accept UserCommand
                if focusAdjustment != 0 [1 / m]
                then coarseSearch;

            transition coarseSearch_to_fineFocus
                first coarseSearch
                if currentFocus >= focusRangeMin and currentFocus <= focusRangeMax
                then fineFocus;

            transition fineFocus_to_locked
                first fineFocus
                if focusStatus == FocusStatus::focused
                then locked;

            transition coarseSearch_to_outOfRange
                first coarseSearch
                if currentFocus < focusRangeMin or currentFocus > focusRangeMax
                then outOfRange;

            transition locked_to_fineFocus
                first locked
                accept UserCommand
                if focusAdjustment != 0 [1 / m]
                then fineFocus;
        }
    }

    part def ImagingSubsystem {
        attribute sensorHorizontalPixels : ImageResolution = 2048;
        attribute sensorVerticalPixels : ImageResolution = 1536;
        attribute frameRate : FrameRate = 30 [Hz];
        attribute exposureTime : ScalarValues::Real {
            unit = ms;
        }
        attribute imageNoiseLevel : ScalarValues::Real;

        port opticalIn : OpticalReturnPort;
        port commandIn : CommandInputPort;
        port imageOut : ImageOutputPort;

        action captureRetinalImage {
            in item focusedOpticalImage : LightEnergy;
            in item command : UserCommand;
            out item retinalImage : RetinalImage;

            first receiveFocusedOpticalImage;
            then setExposure;
            then sampleSensorArray;
            then correctIlluminationFalloff;
            then enhanceVesselContrast;
            then produceDigitalRetinalImage;
            then done;
        }

        state captureState {
            entry; then preview;

            state preview;
            state capturingSingleFrame;
            state streaming;
            state saturated;
            state stored;

            transition preview_to_capturingSingleFrame
                first preview
                accept UserCommand
                if captureRequested
                then capturingSingleFrame;

            transition capturingSingleFrame_to_stored
                first capturingSingleFrame
                then stored;

            transition preview_to_streaming
                first preview
                accept UserCommand
                if requestedMode == ExamMode::digitalCapture
                then streaming;

            transition streaming_to_saturated
                first streaming
                if imageNoiseLevel > 0.8
                then saturated;

            transition saturated_to_preview
                first saturated
                then preview;
        }
    }

    part def ClinicalDisplay {
        attribute displayLuminance : Illuminance;
        attribute displayedFieldOfView : FieldOfViewAngle;
        attribute annotationEnabled : ScalarValues::Boolean;

        port imageIn : ImageOutputPort;
        port observationOut : ObservationOutputPort;

        action presentFundusView {
            in item image : RetinalImage;
            out item observation : ClinicalObservation;

            first receiveRetinalImage;
            then renderOpticDiscAndVessels;
            then allowClinicianInspection;
            then recordClinicalObservation;
            then done;
        }
    }

    part def ControlSubsystem {
        attribute activeMode : ExamMode;
        attribute targetIlluminationStep : ScalarValues::Integer;
        attribute batteryStateOfCharge : ScalarValues::Real;
        attribute deviceTemperature : TemperatureCelsius;

        port commandOut : CommandInputPort;
        port powerMonitorIn : PowerInputPort;

        action coordinateExam {
            in item clinicianCommand : UserCommand;
            out item subsystemCommand : UserCommand;

            first validateCommand;
            then selectExamMode;
            then coordinateIlluminationFocusAndCapture;
            then enforceSafetyLimits;
            then dispatchSubsystemCommand;
            then done;
        }

        state controllerState {
            entry; then poweredOff;

            state poweredOff;
            state selfTest;
            state ready;
            state examining;
            state imageReview;
            state shutdown;
            state fault;

            transition poweredOff_to_selfTest
                first poweredOff
                then selfTest;

            transition selfTest_to_ready
                first selfTest
                if deviceTemperature < 45 [degC]
                then ready;

            transition ready_to_examining
                first ready
                accept UserCommand
                if requestedMode != null
                then examining;

            transition examining_to_imageReview
                first examining
                accept UserCommand
                if captureRequested
                then imageReview;

            transition imageReview_to_examining
                first imageReview
                accept UserCommand
                if requestedMode != null
                then examining;

            transition ready_to_shutdown
                first ready
                then shutdown;

            transition selfTest_to_fault
                first selfTest
                if deviceTemperature >= 45 [degC]
                then fault;
        }
    }

    part def PowerSubsystem {
        attribute batteryCapacity : BatteryCapacity = 3.2 [A * h];
        attribute nominalVoltage : ElectricVoltage = 7.4 [V];
        attribute outputCurrentLimit : ElectricCurrent = 2.0 [A];
        attribute stateOfCharge : ScalarValues::Real;

        port powerOut : PowerOutputPort;

        action supplyRegulatedPower {
            out item regulatedPower : ElectricalPower;

            first measureBatteryVoltage;
            then regulateVoltageRails;
            then limitOutputCurrent;
            then providePowerToSubsystems;
            then done;
        }
    }

    part def Ophthalmoscope {
        attribute primaryFunction : ScalarValues::String =
            "Illuminate the patient's retina through the pupil and provide a magnified, focused view or digital image of the fundus for clinical assessment of the optic disc, macula, and retinal vasculature.";

        part power : PowerSubsystem;
        part controller : ControlSubsystem;
        part illumination : IlluminationSubsystem;
        part optics : OpticalTrain;
        part imager : ImagingSubsystem;
        part display : ClinicalDisplay;

        port clinicianCommandIn : CommandInputPort;
        port patientIlluminationOut : OpticalIlluminationPort;
        port patientRetinalReturnIn : OpticalReturnPort;
        port clinicalImageOut : ImageOutputPort;
        port clinicalObservationOut : ObservationOutputPort;

        connect power.powerOut to illumination.powerIn;
        connect power.powerOut to controller.powerMonitorIn;
        connect controller.commandOut to illumination.commandIn;
        connect controller.commandOut to imager.commandIn;
        connect clinicianCommandIn to controller.commandOut;
        connect illumination.lightOut to patientIlluminationOut;
        connect patientRetinalReturnIn to optics.returnIn;
        connect optics.imageLightOut to imager.opticalIn;
        connect imager.imageOut to display.imageIn;
        connect imager.imageOut to clinicalImageOut;
        connect display.observationOut to clinicalObservationOut;

        action performOphthalmoscopyExam {
            in item command : UserCommand;
            in item retinalReturn : LightEnergy;
            out item image : RetinalImage;
            out item observation : ClinicalObservation;

            first powerOnAndSelfTest;
            then configureExamMode;
            then illuminatePatientRetina;
            then collectRetinalReflection;
            then focusFundusImage;
            then captureOrPresentView;
            then supportClinicalAssessment;
            then completeExam;
            then done;
        }
    }

    part def OphthalmoscopyEncounter {
        part device : Ophthalmoscope;
        part eye : PatientEye;

        connect device.patientIlluminationOut to eye.illuminationIn;
        connect eye.retinalReturnOut to device.patientRetinalReturnIn;
    }

    requirement def PrimaryFunctionRequirement {
        doc
        /* The ophthalmoscopy system shall illuminate the retina through the pupil and provide a focused visual or digital representation of the fundus for clinician assessment. */

        subject system : Ophthalmoscope;

        require constraint {
            system.primaryFunction != "";
        }
    }

    requirement def IlluminationSafetyRequirement {
        doc
        /* The ophthalmoscopy system shall limit optical irradiance at the cornea to a clinically safe configured maximum during all examination modes. */

        subject source : IlluminationSubsystem;

        require constraint {
            source.cornealIrradiance <= source.maxCornealIrradiance;
        }
    }

    requirement def FundusImageQualityRequirement {
        doc
        /* The ophthalmoscopy system shall provide a retinal image with sufficient resolution, field of view, and focus quality to support recognition of the optic disc, macula, and major retinal vessels. */

        subject imager : ImagingSubsystem;

        require constraint {
            imager.sensorHorizontalPixels >= 1600 and
            imager.sensorVerticalPixels >= 1200 and
            imager.frameRate >= 15 [Hz];
        }
    }

    requirement def FocusRangeRequirement {
        doc
        /* The optical train shall compensate for common patient refractive error across at least minus twenty to plus twenty diopters. */

        subject optics : OpticalTrain;

        require constraint {
            optics.focusRangeMin <= -20 [1 / m] and
            optics.focusRangeMax >= 20 [1 / m];
        }
    }

    requirement def PortabilityRequirement {
        doc
        /* The ophthalmoscopy system shall operate from an internal regulated power source suitable for handheld clinical examination. */

        subject power : PowerSubsystem;

        require constraint {
            power.batteryCapacity >= 2.0 [A * h] and
            power.nominalVoltage >= 3.7 [V];
        }
    }

    satisfy PrimaryFunctionRequirement by Ophthalmoscope;
    satisfy IlluminationSafetyRequirement by IlluminationSubsystem;
    satisfy FundusImageQualityRequirement by ImagingSubsystem;
    satisfy FocusRangeRequirement by OpticalTrain;
    satisfy PortabilityRequirement by PowerSubsystem;
}