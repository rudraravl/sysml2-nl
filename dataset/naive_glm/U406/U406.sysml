package SurgicalLightingSystem {
    import ScalarValues::*;

    // ---- Value Types ----
    value type LuminousFlux :> Real { unit "lm"; }
    value type ColorTemperature :> Real { unit "K"; }
    value type BeamDiameter :> Real { unit "cm"; }
    value type TemperatureCelsius :> Real { unit "degC"; }
    value type DistanceMeters :> Real { unit "m"; }
    value type VoltageDC :> Real { unit "V"; }
    value type CurrentDC :> Real { unit "A"; }
    value type PowerWatts :> Real { unit "W"; }
    value type BrightnessPercent :> Real { unit "%"; }
    value type AirFlowRate :> Real { unit "m3/min"; }
    value type AngularPosition :> Real { unit "deg"; }
    value type Frequency :> Real { unit "Hz"; }
    value type ACVoltage :> Real { unit "V"; }

    // ---- Enumerations ----
    enum LightingMode {
        SurgicalMode,
        ExaminationMode,
        EndoscopyMode
    }

    enum SystemPowerState {
        Off,
        Standby,
        Active
    }

    enum FanSpeedLevel {
        Off,
        Normal,
        Boosted
    }

    // ---- Item Definitions ----
    item def LightBeam {
        attribute luminousFlux : LuminousFlux;
        attribute colorTemperature : ColorTemperature;
        attribute beamDiameter : BeamDiameter;
    }

    item def DCPower {
        attribute voltage : VoltageDC;
        attribute current : CurrentDC;
    }

    item def ACPower {
        attribute voltage : ACVoltage;
        attribute frequency : Frequency;
    }

    item def Command {
        attribute commandType : String;
        attribute value : Real;
    }

    item def TemperatureReading {
        attribute value : TemperatureCelsius;
    }

    item def AirFlow {
        attribute flowRate : AirFlowRate;
    }

    item def ModeConfiguration {
        attribute mode : LightingMode;
        attribute brightness : BrightnessPercent;
        attribute colorTemperature : ColorTemperature;
        attribute beamDiameter : BeamDiameter;
    }

    // ---- Port Definitions ----
    port def DCPowerOut {
        out item power : DCPower;
    }

    port def DCPowerIn {
        in item power : DCPower;
    }

    port def ACPowerIn {
        in item power : ACPower;
    }

    port def CommandOut {
        out item command : Command;
    }

    port def CommandIn {
        in item command : Command;
    }

    port def LightOut {
        out item beam : LightBeam;
    }

    port def LightIn {
        in item beam : LightBeam;
    }

    port def TemperatureOut {
        out item reading : TemperatureReading;
    }

    port def TemperatureIn {
        in item reading : TemperatureReading;
    }

    port def AirOut {
        out item air : AirFlow;
    }

    // ---- LED Module (60 LEDs) ----
    part def LEDModule {
        attribute ledCount : Integer = 60;
        attribute maxLuminousFlux : LuminousFlux = 160000;
        attribute currentBrightness : BrightnessPercent = 0;
        attribute currentColorTemp : ColorTemperature = 4500;
        attribute powerConsumption : PowerWatts = 350;

        port powerIn : DCPowerIn;
        port controlIn : CommandIn;
        port lightOut : LightOut;

        action generateLight {
            in brightness : BrightnessPercent;
            in colorTemp : ColorTemperature;
            out beam : LightBeam;
        }

        perform generateLight;

        state ledState {
            initial state Dark;
            state Illuminating;
            transition dark_to_illuminating
                first Dark then Illuminating
                accept Command
                if controlIn.command.commandType == "powerOn";
            transition illuminating_to_dark
                first Illuminating then Dark
                accept Command
                if controlIn.command.commandType == "powerOff";
        }
    }

    // ---- Optical Assembly ----
    part def OpticalAssembly {
        attribute minBeamDiameter : BeamDiameter = 10;
        attribute maxBeamDiameter : BeamDiameter = 35;
        attribute currentBeamDiameter : BeamDiameter = 20;
        attribute lensCount : Integer = 5;

        port lightIn : LightIn;
        port lightOut : LightOut;
        port controlIn : CommandIn;

        action focusBeam {
            in inputBeam : LightBeam;
            in targetDiameter : BeamDiameter;
            out focusedBeam : LightBeam;
        }

        perform focusBeam;

        action adjustBeamDiameter {
            in targetDiameter : BeamDiameter;
        }

        perform adjustBeamDiameter;
    }

    // ---- Cooling Fan ----
    part def CoolingFan {
        attribute maxFlowRate : AirFlowRate = 2.0;
        attribute currentSpeedPercent : Real = 0;
        attribute currentLevel : FanSpeedLevel = FanSpeedLevel::Off;

        port powerIn : DCPowerIn;
        port controlIn : CommandIn;
        port airOut : AirOut;

        action circulateAir {
            out air : AirFlow;
        }

        perform circulateAir;

        state fanState {
            initial state FanOff;
            state FanNormal {
                entry action { currentSpeedPercent = 40; currentLevel = FanSpeedLevel::Normal; }
            }
            state FanBoosted {
                entry action { currentSpeedPercent = 100; currentLevel = FanSpeedLevel::Boosted; }
            }

            transition off_to_normal
                first FanOff then FanNormal
                accept Command
                if controlIn.command.commandType == "fanOn";

            transition normal_to_boosted
                first FanNormal then FanBoosted
                accept Command
                if controlIn.command.commandType == "fanSpeed" and controlIn.command.value > 45.0;

            transition boosted_to_normal
                first FanBoosted then FanNormal
                accept Command
                if controlIn.command.commandType == "fanSpeed" and controlIn.command.value <= 45.0;

            transition normal_to_off
                first FanNormal then FanOff
                accept Command
                if controlIn.command.commandType == "fanOff";

            transition boosted_to_off
                first FanBoosted then FanOff
                accept Command
                if controlIn.command.commandType == "fanOff";
        }
    }

    // ---- Temperature Sensor ----
    part def TemperatureSensor {
        attribute maxSafeTemp : TemperatureCelsius = 40.0;
        attribute currentTemp : TemperatureCelsius = 25.0;
        attribute samplingRate : Frequency = 2.0;

        port thermalOut : TemperatureOut;

        action measureTemperature {
            out reading : TemperatureReading;
        }

        perform measureTemperature;

        action evaluateSafety {
            in temp : TemperatureCelsius;
            out isSafe : Boolean;
        }

        perform evaluateSafety;
    }

    // ---- Sterile Handle ----
    part def SterileHandle {
        attribute isAutoclavable : Boolean = true;
        attribute isAttached : Boolean = true;
        attribute material : String = "MedicalGradePolymer";

        port commandOut : CommandOut;

        action detectRepositioning {
            out command : Command;
        }

        perform detectRepositioning;

        action detectBrightnessAdjust {
            out command : Command;
        }

        perform detectBrightnessAdjust;
    }

    // ---- Light Head ----
    part def LightHead {
        attribute surfaceTemp : TemperatureCelsius = 25.0;
        attribute housingMaterial : String = "AluminumAlloy";

        part ledModule : LEDModule;
        part opticalAssembly : OpticalAssembly;
        part coolingFan : CoolingFan;
        part temperatureSensor : TemperatureSensor;
        part sterileHandle : SterileHandle;

        connection ledToOptical
            connect ledModule.lightOut to opticalAssembly.lightIn;

        connection sensorThermalOut
            connect temperatureSensor.thermalOut to coolingFan.controlIn;
    }

    // ---- Articulating Arm ----
    part def ArticulatingArm {
        attribute maxReach : DistanceMeters = 2.0;
        attribute jointCount : Integer = 6;
        attribute isLocked : Boolean = false;
        attribute shoulderAngle : AngularPosition = 0;
        attribute elbowAngle : AngularPosition = 0;
        attribute wristAngle : AngularPosition = 0;
        attribute baseRotation : AngularPosition = 0;

        port controlIn : CommandIn;

        action positionLight {
            in targetX : DistanceMeters;
            in targetY : DistanceMeters;
            in targetZ : DistanceMeters;
        }

        perform positionLight;

        action lockJoints {
            out locked : Boolean;
        }

        perform lockJoints;

        action unlockJoints {
            out unlocked : Boolean;
        }

        perform unlockJoints;

        state armState {
            initial state Unlocked;
            state Locked;
            transition unlock_to_lock
                first Unlocked then Locked
                accept Command
                if controlIn.command.commandType == "lockArm";
            transition lock_to_unlock
                first Locked then Unlocked
                accept Command
                if controlIn.command.commandType == "unlockArm";
        }
    }

    // ---- Central Control Unit ----
    part def CentralControlUnit {
        attribute powerState : SystemPowerState = SystemPowerState::Off;
        attribute currentMode : LightingMode = LightingMode::SurgicalMode;
        attribute currentBrightness : BrightnessPercent = 0;

        attribute surgicalConfig : ModeConfiguration = ModeConfiguration{
            mode = LightingMode::SurgicalMode,
            brightness = 100,
            colorTemperature = 4500,
            beamDiameter = 20
        };

        attribute examinationConfig : ModeConfiguration = ModeConfiguration{
            mode = LightingMode::ExaminationMode,
            brightness = 60,
            colorTemperature = 4000,
            beamDiameter = 35
        };

        attribute endoscopyConfig : ModeConfiguration = ModeConfiguration{
            mode = LightingMode::EndoscopyMode,
            brightness = 30,
            colorTemperature = 5000,
            beamDiameter = 10
        };

        port commandIn : CommandIn;
        port temperatureIn : TemperatureIn;
        port powerIn : DCPowerIn;
        port ledControlOut : CommandOut;
        port opticalControlOut : CommandOut;
        port fanControlOut : CommandOut;
        port armControlOut : CommandOut;
        port powerSupplyControlOut : CommandOut;

        action processCommand {
            in cmd : Command;
        }

        perform processCommand;

        action adjustBrightness {
            in level : BrightnessPercent;
        }

        perform adjustBrightness;

        action setPosition {
            in x : DistanceMeters;
            in y : DistanceMeters;
            in z : DistanceMeters;
        }

        perform setPosition;

        action selectMode {
            in mode : LightingMode;
        }

        perform selectMode;

        action evaluateThermalSafety {
            in tempReading : TemperatureReading;
            out fanCommand : Command;
        }

        perform evaluateThermalSafety;

        state controlStateMachine {
            initial state SystemOff;

            state Standby;

            state SurgicalModeActive {
                entry action {
                    currentMode = LightingMode::SurgicalMode;
                    currentBrightness = 100;
                }
            }

            state ExaminationModeActive {
                entry action {
                    currentMode = LightingMode::ExaminationMode;
                    currentBrightness = 60;
                }
            }

            state EndoscopyModeActive {
                entry action {
                    currentMode = LightingMode::EndoscopyMode;
                    currentBrightness = 30;
                }
            }

            transition off_to_standby
                first SystemOff then Standby
                accept Command
                if commandIn.command.commandType == "powerOn";

            transition standby_to_off
                first Standby then SystemOff
                accept Command
                if commandIn.command.commandType == "powerOff";

            transition standby_to_surgical
                first Standby then SurgicalModeActive
                accept Command
                if commandIn.command.commandType == "setMode" and commandIn.command.value == 0;

            transition standby_to_examination
                first Standby then ExaminationModeActive
                accept Command
                if commandIn.command.commandType == "setMode" and commandIn.command.value == 1;

            transition standby_to_endoscopy
                first Standby then EndoscopyModeActive
                accept Command
                if commandIn.command.commandType == "setMode" and commandIn.command.value == 2;

            transition surgical_to_standby
                first SurgicalModeActive then Standby
                accept Command
                if commandIn.command.commandType == "standby";

            transition examination_to_standby
                first ExaminationModeActive then Standby
                accept Command
                if commandIn.command.commandType == "standby";

            transition endoscopy_to_standby
                first EndoscopyModeActive then Standby
                accept Command
                if commandIn.command.commandType == "standby";

            transition surgical_to_examination
                first SurgicalModeActive then ExaminationModeActive
                accept Command
                if commandIn.command.commandType == "setMode" and commandIn.command.value == 1;

            transition surgical_to_endoscopy
                first SurgicalModeActive then EndoscopyModeActive
                accept Command
                if commandIn.command.commandType == "setMode" and commandIn.command.value == 2;

            transition examination_to_surgical
                first ExaminationModeActive then SurgicalModeActive
                accept Command
                if commandIn.command.commandType == "setMode" and commandIn.command.value == 0;

            transition examination_to_endoscopy
                first ExaminationModeActive then EndoscopyModeActive
                accept Command
                if commandIn.command.commandType == "setMode" and commandIn.command.value == 2;

            transition endoscopy_to_surgical
                first EndoscopyModeActive then SurgicalModeActive
                accept Command
                if commandIn.command.commandType == "setMode" and commandIn.command.value == 0;

            transition endoscopy_to_examination
                first EndoscopyModeActive then ExaminationModeActive
                accept Command
                if commandIn.command.commandType == "setMode" and commandIn.command.value == 1;
        }
    }

    // ---- Power Supply ----
    part def PowerSupply {
        attribute inputVoltage : ACVoltage = 230;
        attribute inputFrequency : Frequency = 50;
        attribute outputVoltage : VoltageDC = 48;
        attribute maxOutputPower : PowerWatts = 500;
        attribute efficiency : Real = 0.92;
        attribute isProtected : Boolean = true;

        port acIn : ACPowerIn;
        port dcOut : DCPowerOut;
        port controlIn : CommandIn;

        action convertPower {
            in ac : ACPower;
            out dc : DCPower;
        }

        perform convertPower;

        action regulateOutput {
            in targetVoltage : VoltageDC;
            out dc : DCPower;
        }

        perform regulateOutput;

        state supplyState {
            initial state SupplyOff;
            state SupplyOn;
            state FaultCondition;

            transition off_to_on
                first SupplyOff then SupplyOn
                accept Command
                if controlIn.command.commandType == "powerOn";

            transition on_to_off
                first SupplyOn then SupplyOff
                accept Command
                if controlIn.command.commandType == "powerOff";

            transition on_to_fault
                first SupplyOn then FaultCondition
                accept Command
                if controlIn.command.commandType == "overload";

            transition fault_to_off
                first FaultCondition then SupplyOff
                accept Command
                if controlIn.command.commandType == "reset";
        }
    }

    // ---- Top-Level Surgical Lighting System ----
    part def SurgicalLightingSystem {
        attribute systemId : String = "SLS-001";
        attribute manufacturer : String = "MedicalLightingCorp";
        attribute model : String = "SurgeLight-Pro";

        part controlUnit : CentralControlUnit;
        part powerSupply : PowerSupply;
        part articulatingArm : ArticulatingArm;
        part lightHead : LightHead;

        connection acToSupply
            connect powerSupply.acIn to powerSupply.acIn;

        connection powerToControl
            connect powerSupply.dcOut to controlUnit.powerIn;

        connection powerToLED
            connect powerSupply.dcOut to lightHead.ledModule.powerIn;

        connection powerToFan
            connect powerSupply.dcOut to lightHead.coolingFan.powerIn;

        connection controlToLED
            connect controlUnit.ledControlOut to lightHead.ledModule.controlIn;

        connection controlToOptical
            connect controlUnit.opticalControlOut to lightHead.opticalAssembly.controlIn;

        connection controlToFan
            connect controlUnit.fanControlOut to lightHead.coolingFan.controlIn;

        connection controlToArm
            connect controlUnit.armControlOut to articulatingArm.controlIn;

        connection controlToPowerSupply
            connect controlUnit.powerSupplyControlOut to powerSupply.controlIn;

        connection handleToControl
            connect lightHead.sterileHandle.commandOut to controlUnit.commandIn;

        connection sensorToControl
            connect lightHead.temperatureSensor.thermalOut to controlUnit.temperatureIn;
    }

    // ---- Requirements ----
    requirement def IlluminationQualityRequirement {
        subject : lightingSystem : SurgicalLightingSystem;

        doc /* The system shall provide high-quality, adjustable illumination of the surgical field for precise visualization of anatomical structures. */

        requirement minLuminousFluxRequirement {
            subject : lightingSystem;
            doc /* The LED module shall generate at least 160,000 lumens at full brightness. */
            assert { lightingSystem.lightHead.ledModule.maxLuminousFlux >= 160000 }
        }

        requirement ledCountRequirement {
            subject : lightingSystem;
            doc /* The LED module shall contain exactly 60 LEDs. */
            assert { lightingSystem.lightHead.ledModule.ledCount == 60 }
        }

        requirement adjustableBeamRequirement {
            subject : lightingSystem;
            doc /* The optical assembly shall provide an adjustable beam diameter between 10 cm and 35 cm. */
            assert { lightingSystem.lightHead.opticalAssembly.minBeamDiameter <= 10 }
            assert { lightingSystem.lightHead.opticalAssembly.maxBeamDiameter >= 35 }
        }
    }

    requirement def ArmReachRequirement {
        subject : lightingSystem : SurgicalLightingSystem;

        doc /* The articulating arm shall allow positioning of the light head up to 2 meters from the mounting point. */
        assert { lightingSystem.articulatingArm.maxReach >= 2.0 }
    }

    requirement def ArmLockingRequirement {
        subject : lightingSystem : SurgicalLightingSystem;

        doc /* The articulating arm shall be lockable into a stable position to hold the light head steady during procedures. */
        assert { lightingSystem.articulatingArm.jointCount >= 4 }
    }

    requirement def ArmMultiJointRequirement {
        subject : lightingSystem : SurgicalLightingSystem;

        doc /* The articulating arm shall be multi-jointed to enable flexible positioning. */
        assert { lightingSystem.articulatingArm.jointCount >= 5 }
    }

    requirement def SterileHandleRequirement {
        subject : lightingSystem : SurgicalLightingSystem;

        doc /* The system shall include a sterile, autoclavable handle allowing surgeons to reposition the light during procedures without compromising the sterile environment. */
        assert { lightingSystem.lightHead.sterileHandle.isAutoclavable == true }
        assert { lightingSystem.lightHead.sterileHandle.isAttached == true }
    }

    requirement def ThermalSafetyRequirement {
        subject : lightingSystem : SurgicalLightingSystem;

        doc /* The light head surface temperature shall not exceed 40 degrees Celsius during operation to ensure patient and staff safety. */
        assert { lightingSystem.lightHead.temperatureSensor.maxSafeTemp <= 40.0 }
    }

    requirement def CoolingControlRequirement {
        subject : lightingSystem : SurgicalLightingSystem;

        doc /* A dedicated cooling fan shall be controlled based on feedback from a temperature sensor to maintain safe surface temperature. */
        assert { lightingSystem.lightHead.coolingFan.maxFlowRate >= 1.0 }
    }

    requirement def OperatingModesRequirement {
        subject : lightingSystem : SurgicalLightingSystem;

        doc /* The system shall support Surgical, Examination, and Endoscopy modes with specific brightness, color temperature, and beam diameter settings. */

        requirement surgicalModeConfigRequirement {
            subject : lightingSystem;
            doc /* Surgical Mode shall provide 100 percent brightness, 4500K color temperature, and 20 cm beam diameter. */
            assert { lightingSystem.controlUnit.surgicalConfig.brightness == 100 }
            assert { lightingSystem.controlUnit.surgicalConfig.colorTemperature == 4500 }
            assert { lightingSystem.controlUnit.surgicalConfig.beamDiameter == 20 }
        }

        requirement examinationModeConfigRequirement {
            subject : lightingSystem;
            doc /* Examination Mode shall provide 60 percent brightness, 4000K color temperature, and 35 cm beam diameter. */
            assert { lightingSystem.controlUnit.examinationConfig.brightness == 60 }
            assert { lightingSystem.controlUnit.examinationConfig.colorTemperature == 4000 }
            assert { lightingSystem.controlUnit.examinationConfig.beamDiameter == 35 }
        }

        requirement endoscopyModeConfigRequirement {
            subject : lightingSystem;
            doc /* Endoscopy Mode shall provide 30 percent brightness, 5000K color temperature, and 10 cm beam diameter. */
            assert { lightingSystem.controlUnit.endoscopyConfig.brightness == 30 }
            assert { lightingSystem.controlUnit.endoscopyConfig.colorTemperature == 5000 }
            assert { lightingSystem.controlUnit.endoscopyConfig.beamDiameter == 10 }
        }
    }

    requirement def PowerConversionRequirement {
        subject : lightingSystem : SurgicalLightingSystem;

        doc /* The power supply shall convert standard AC wall power to low-voltage DC needed by the LEDs and electronics. */
        assert { lightingSystem.powerSupply.outputVoltage <= 60 }
        assert { lightingSystem.powerSupply.inputVoltage >= 100 }
    }

    requirement def CentralControlRequirement {
        subject : lightingSystem : SurgicalLightingSystem;

        doc /* A central control unit shall manage the entire system, receiving commands to turn the light on or off, adjust brightness, and define position. */
        assert { lightingSystem.controlUnit.powerState == SystemPowerState::Off or lightingSystem.controlUnit.powerState == SystemPowerState::Standby or lightingSystem.controlUnit.powerState == SystemPowerState::Active }
    }

    requirement def PatientStaffSafetyRequirement {
        subject : lightingSystem : SurgicalLightingSystem;

        doc /* The system shall ensure patient and staff safety during all operating modes. */

        satisfy ThermalSafetyRequirement by lightingSystem;
        satisfy CoolingControlRequirement by lightingSystem;
    }

    // ---- System Instance and Requirement Satisfaction ----
    part surgicalLightingSystem : SurgicalLightingSystem;

    satisfy IlluminationQualityRequirement by surgicalLightingSystem;
    satisfy ArmReachRequirement by surgicalLightingSystem;
    satisfy ArmLockingRequirement by surgicalLightingSystem;
    satisfy ArmMultiJointRequirement by surgicalLightingSystem;
    satisfy SterileHandleRequirement by surgicalLightingSystem;
    satisfy ThermalSafetyRequirement by surgicalLightingSystem;
    satisfy CoolingControlRequirement by surgicalLightingSystem;
    satisfy OperatingModesRequirement by surgicalLightingSystem;
    satisfy PowerConversionRequirement by surgicalLightingSystem;
    satisfy CentralControlRequirement by surgicalLightingSystem;
    satisfy PatientStaffSafetyRequirement by surgicalLightingSystem;
}
