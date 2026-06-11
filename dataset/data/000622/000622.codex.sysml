package HeineOptotechnikDiagnosticSystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    value def LuminousFlux {
        unit = "lm";
        quantityKind = "luminous flux";
    }

    value def Illuminance {
        unit = "lx";
        quantityKind = "illuminance";
    }

    value def ColorTemperature {
        unit = "K";
        quantityKind = "color temperature";
    }

    value def ElectricPotential {
        unit = "V";
        quantityKind = "electric potential";
    }

    value def ElectricCurrent {
        unit = "A";
        quantityKind = "electric current";
    }

    value def ElectricCharge {
        unit = "mAh";
        quantityKind = "battery capacity";
    }

    value def Power {
        unit = "W";
        quantityKind = "power";
    }

    value def Temperature {
        unit = "degC";
        quantityKind = "temperature";
    }

    value def Mass {
        unit = "g";
        quantityKind = "mass";
    }

    value def Length {
        unit = "mm";
        quantityKind = "length";
    }

    value def TimeDuration {
        unit = "s";
        quantityKind = "duration";
    }

    item def ElectricalEnergy {
        attribute voltage : ElectricPotential;
        attribute current : ElectricCurrent;
        attribute power : Power;
    }

    item def OpticalBeam {
        attribute luminousFlux : LuminousFlux;
        attribute illuminanceAtTarget : Illuminance;
        attribute colorTemperature : ColorTemperature;
        attribute beamDiameter : Length;
    }

    item def TissueImage {
        attribute fieldOfView : Length;
        attribute magnification : Real;
        attribute contrastLevel : Real;
        attribute isClinicallyUsable : Boolean;
    }

    item def UserCommand {
        attribute requestedPowerOn : Boolean;
        attribute brightnessLevel : Real;
        attribute selectedInstrumentHead : String;
    }

    item def DiagnosticObservation {
        attribute anatomicalRegion : String;
        attribute visibleFinding : String;
        attribute confidence : Real;
    }

    port def ElectricalPowerPort {
        out item energy : ElectricalEnergy;
    }

    port def OpticalOutputPort {
        out item beam : OpticalBeam;
    }

    port def ImageOutputPort {
        out item image : TissueImage;
    }

    port def CommandInputPort {
        in item command : UserCommand;
    }

    port def ObservationOutputPort {
        out item observation : DiagnosticObservation;
    }

    port def ChargingPort {
        in item chargingEnergy : ElectricalEnergy;
    }

    part def RechargeableHandle {
        attribute nominalVoltage : ElectricPotential = 3.5 [V];
        attribute batteryCapacity : ElectricCharge = 2500 [mAh];
        attribute maximumContinuousPower : Power = 8.0 [W];
        attribute handleMass : Mass = 145 [g];
        attribute gripDiameter : Length = 28 [mm];

        port powerOut : ElectricalPowerPort;
        port chargeIn : ChargingPort;
        port commandIn : CommandInputPort;

        state def HandlePowerState {
            state off;
            state standby;
            state supplyingPower;
            state charging;
            state lowBattery;

            entry action initializeElectronics;
            transition first off;

            transition off_to_standby
                first off then standby
                accept commandIn.command
                if commandIn.command.requestedPowerOn;

            transition standby_to_supply
                first standby then supplyingPower
                accept commandIn.command
                if commandIn.command.brightnessLevel > 0.0;

            transition supply_to_standby
                first supplyingPower then standby
                accept commandIn.command
                if commandIn.command.brightnessLevel == 0.0;

            transition any_to_charging
                first off then charging
                accept chargeIn.chargingEnergy
                if chargeIn.chargingEnergy.voltage >= 4.5 [V];

            transition supply_to_low
                first supplyingPower then lowBattery
                if batteryCapacity < 150 [mAh];

            transition low_to_off
                first lowBattery then off
                accept commandIn.command
                if not commandIn.command.requestedPowerOn;
        }
    }

    part def LEDIlluminationModule {
        attribute ledColorTemperature : ColorTemperature = 4000 [K];
        attribute maximumFlux : LuminousFlux = 120 [lm];
        attribute regulatedCurrent : ElectricCurrent = 0.9 [A];
        attribute thermalLimit : Temperature = 42 [degC];
        attribute opticalEfficiency : Real = 0.72;

        port electricalIn : ElectricalPowerPort;
        port opticalOut : OpticalOutputPort;
        port commandIn : CommandInputPort;

        action def RegulateBrightness {
            in desiredLevel : Real;
            in availablePower : Power;
            out emittedFlux : LuminousFlux;

            assert desiredLevel >= 0.0 and desiredLevel <= 1.0;
            emittedFlux = desiredLevel * maximumFlux;
        }

        state def IlluminationState {
            state dark;
            state ramping;
            state stableIllumination;
            state thermalReduced;
            state faultOff;

            transition first dark;

            transition dark_to_ramping
                first dark then ramping
                accept commandIn.command
                if commandIn.command.brightnessLevel > 0.0;

            transition ramping_to_stable
                first ramping then stableIllumination
                after 1 [s];

            transition stable_to_reduced
                first stableIllumination then thermalReduced
                if thermalLimit < 42 [degC];

            transition reduced_to_fault
                first thermalReduced then faultOff
                if thermalLimit > 48 [degC];

            transition stable_to_dark
                first stableIllumination then dark
                accept commandIn.command
                if commandIn.command.brightnessLevel == 0.0;
        }
    }

    part def OpticalHead {
        attribute headType : String = "direct ophthalmoscope and otoscope compatible diagnostic head";
        attribute workingDistance : Length = 25 [mm];
        attribute apertureDiameter : Length = 3.0 [mm];
        attribute magnification : Real = 3.5;
        attribute fieldDiameter : Length = 35 [mm];

        port illuminationIn : OpticalOutputPort;
        port imageOut : ImageOutputPort;

        part collimatingLens {
            attribute focalLength : Length = 18 [mm];
            attribute clearAperture : Length = 8 [mm];
        }

        part viewingLens {
            attribute magnification : Real = 3.5;
            attribute distortionPercent : Real = 1.5;
        }

        part apertureSelector {
            attribute selectedAperture : String = "medium";
            attribute smallAperture : Length = 1.0 [mm];
            attribute mediumAperture : Length = 3.0 [mm];
            attribute largeAperture : Length = 5.0 [mm];
        }

        action def FormDiagnosticImage {
            in beam : OpticalBeam;
            out image : TissueImage;

            image.magnification = magnification;
            image.fieldOfView = fieldDiameter;
            image.contrastLevel = 0.85;
            image.isClinicallyUsable = beam.illuminanceAtTarget >= 1200 [lx];
        }
    }

    part def ClinicianInterface {
        attribute brightnessSetting : Real = 0.65;
        attribute selectedHead : String = "ophthalmoscope";
        attribute switchCyclesLife : Integer = 100000;

        port commandOut : CommandInputPort;
        port imageIn : ImageOutputPort;
        port observationOut : ObservationOutputPort;

        action def AdjustBrightness {
            in requestedSetting : Real;
            out command : UserCommand;

            assert requestedSetting >= 0.0 and requestedSetting <= 1.0;
            command.requestedPowerOn = requestedSetting > 0.0;
            command.brightnessLevel = requestedSetting;
            command.selectedInstrumentHead = selectedHead;
        }

        action def InterpretImage {
            in image : TissueImage;
            out observation : DiagnosticObservation;

            observation.anatomicalRegion = selectedHead == "ophthalmoscope" ? "retina" : "ear canal";
            observation.visibleFinding = image.isClinicallyUsable ? "illuminated anatomical structure visible" : "image quality insufficient";
            observation.confidence = image.isClinicallyUsable ? 0.9 : 0.3;
        }
    }

    part def ChargingBase {
        attribute inputVoltage : ElectricPotential = 120 [V];
        attribute outputVoltage : ElectricPotential = 4.8 [V];
        attribute maximumChargeCurrent : ElectricCurrent = 1.2 [A];
        attribute fullChargeTime : TimeDuration = 7200 [s];

        port chargeOut : ChargingPort;
    }

    part def HeineOptotechnikBasedDiagnosticInstrument {
        attribute primaryFunction : String =
            "Provide bright, color-neutral, coaxial illumination and magnified optical viewing so a clinician can inspect small anatomical structures such as the retina or ear canal during point-of-care examination.";

        part handle : RechargeableHandle;
        part illumination : LEDIlluminationModule;
        part opticalHead : OpticalHead;
        part userInterface : ClinicianInterface;
        part charger : ChargingBase;

        port clinicianCommand : CommandInputPort;
        port clinicalObservation : ObservationOutputPort;

        connect clinicianCommand to userInterface.commandOut;
        connect userInterface.commandOut to handle.commandIn;
        connect userInterface.commandOut to illumination.commandIn;
        connect handle.powerOut to illumination.electricalIn;
        connect illumination.opticalOut to opticalHead.illuminationIn;
        connect opticalHead.imageOut to userInterface.imageIn;
        connect userInterface.observationOut to clinicalObservation;
        connect charger.chargeOut to handle.chargeIn;

        action def PerformHighLevelDiagnosticExamination {
            in command : UserCommand;
            out observation : DiagnosticObservation;

            objective {
                "Convert clinician power and brightness commands into regulated optical illumination, project the beam through a precision diagnostic head, form a magnified tissue image, and support a clinical visual observation.";
            }

            send command to clinicianCommand;
            exhibit state handle.HandlePowerState::supplyingPower;
            exhibit state illumination.IlluminationState::stableIllumination;
            observation.anatomicalRegion = command.selectedInstrumentHead == "ophthalmoscope" ? "retina" : "ear canal";
            observation.visibleFinding = "illuminated and magnified anatomy available for clinician assessment";
            observation.confidence = 0.9;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject instrument : HeineOptotechnikBasedDiagnosticInstrument;

        doc
            /* The system shall provide portable, clinician-controlled optical illumination and magnified viewing for visual examination of small anatomical structures. */

        require constraint {
            instrument.primaryFunction != "";
        }
    }

    requirement def IlluminationRequirement {
        subject illumination : LEDIlluminationModule;

        doc
            /* The illumination module shall provide color-neutral LED light suitable for diagnostic visual inspection. */

        require constraint {
            illumination.ledColorTemperature >= 3500 [K] and
            illumination.ledColorTemperature <= 4500 [K] and
            illumination.maximumFlux >= 80 [lm];
        }
    }

    requirement def PortabilityRequirement {
        subject handle : RechargeableHandle;

        doc
            /* The diagnostic instrument shall be hand-held and rechargeable for point-of-care use. */

        require constraint {
            handle.handleMass <= 180 [g] and
            handle.nominalVoltage == 3.5 [V] and
            handle.batteryCapacity >= 2000 [mAh];
        }
    }

    requirement def OpticalViewingRequirement {
        subject head : OpticalHead;

        doc
            /* The optical head shall magnify the illuminated anatomical target while maintaining a clinically useful field of view. */

        require constraint {
            head.magnification >= 3.0 and
            head.fieldDiameter >= 25 [mm] and
            head.apertureDiameter >= 1.0 [mm];
        }
    }

    requirement def ThermalSafetyRequirement {
        subject illumination : LEDIlluminationModule;

        doc
            /* The device shall reduce or stop illumination before external contact temperature becomes unsafe. */

        require constraint {
            illumination.thermalLimit <= 42 [degC];
        }
    }

    requirement def UsabilityRequirement {
        subject interface : ClinicianInterface;

        doc
            /* The clinician shall be able to select illumination intensity and instrument head mode during examination. */

        require constraint {
            interface.brightnessSetting >= 0.0 and
            interface.brightnessSetting <= 1.0 and
            interface.selectedHead != "";
        }
    }

    satisfy PrimaryFunctionRequirement by HeineOptotechnikBasedDiagnosticInstrument;
    satisfy IlluminationRequirement by LEDIlluminationModule;
    satisfy PortabilityRequirement by RechargeableHandle;
    satisfy OpticalViewingRequirement by OpticalHead;
    satisfy ThermalSafetyRequirement by LEDIlluminationModule;
    satisfy UsabilityRequirement by ClinicianInterface;

    part diagnosticSystem : HeineOptotechnikBasedDiagnosticInstrument;

}