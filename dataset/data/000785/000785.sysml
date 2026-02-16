package 'Surgical Lighting System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def IlluminanceLevel :> ISQ::IlluminanceValue;
    attribute def ColorTemperature :> ISQ::ThermodynamicTemperatureValue;
    attribute def BeamDiameter :> ISQ::LengthValue;
    attribute def IntensityPercent :> Real;
    
    attribute def LightingModeType {
        attribute modeName : String;
        attribute targetIlluminance : IlluminanceLevel;
        attribute targetColorTemp : ColorTemperature;
        attribute targetBeamDiameter : BeamDiameter;
    }
    
    item def PowerCommand {
        attribute isOn : Boolean;
    }
    
    item def IntensityCommand {
        attribute level : IntensityPercent;
    }
    
    item def PositionCommand {
        attribute xOffset : ISQ::LengthValue;
        attribute yOffset : ISQ::LengthValue;
        attribute zHeight : ISQ::LengthValue;
    }
    
    item def LightOutput {
        attribute illuminance : IlluminanceLevel;
        attribute colorTemp : ColorTemperature;
        attribute beamDiameter : BeamDiameter;
    }
    
    item def SensorData {
        attribute headTemperature : ISQ::ThermodynamicTemperatureValue;
        attribute ambientIlluminance : IlluminanceLevel;
    }
    
    port def PowerPort {
        in attribute voltage : ISQ::ElectricPotentialValue;
        in attribute current : ISQ::ElectricCurrentValue;
    }
    
    port def ControlInputPort {
        in powerCmd : PowerCommand;
        in intensityCmd : IntensityCommand;
        in positionCmd : PositionCommand;
    }
    
    port def LightOutputPort {
        out lightBeam : LightOutput;
    }
    
    port def SensorOutputPort {
        out sensorData : SensorData;
    }
    
    part def PowerSupply {
        port acInput : PowerPort;
        port dcOutput : PowerPort;
        
        attribute inputVoltage : ISQ::ElectricPotentialValue = 230.0 [SI::V];
        attribute outputVoltage : ISQ::ElectricPotentialValue = 24.0 [SI::V];
        attribute maxCurrent : ISQ::ElectricCurrentValue = 8.0 [SI::A];
    }
    
    part def LEDModule {
        port powerIn : PowerPort;
        port lightOut : LightOutputPort;
        
        attribute numberOfLEDs : Integer = 60;
        attribute maxLuminousFlux : ISQ::LuminousFluxValue = 30000.0 [SI::lm];
        attribute nominalColorTemp : ColorTemperature = 4500.0 [SI::K];
        attribute currentIlluminance : IlluminanceLevel;
    }
    
    part def OpticalAssembly {
        port lightIn : LightOutputPort;
        port focusedLightOut : LightOutputPort;
        
        attribute lensCount : Integer = 4;
        attribute beamAngle : ISQ::PlaneAngleValue = 20.0 [SI::'°'];
        attribute focusRange : BeamDiameter[2] = (100.0 [SI::mm], 300.0 [SI::mm]);
    }
    
    part def CoolingFan {
        port powerIn : PowerPort;
        
        attribute fanSpeed : Real = 2500.0;
        attribute airflowRate : Real = 45.0;
        attribute maxHeatDissipation : ISQ::PowerValue = 160.0 [SI::W];
    }
    
    part def ControlUnit {
        port controlIn : ControlInputPort;
        port sensorIn : SensorOutputPort;
        port ledControl : PowerPort;
        port fanControl : PowerPort;
        
        attribute currentMode : LightingModeType;
        attribute currentIntensity : IntensityPercent = 80.0;
    }
    
    part def ArticulatingArm {
        port positionIn : PositionCommand;
        
        attribute numberOfJoints : Integer = 5;
        attribute maxReach : ISQ::LengthValue = 2.0 [SI::m];
        attribute payloadCapacity : ISQ::MassValue = 8.0 [SI::kg];
        attribute lockingEnabled : Boolean = true;
    }
    
    part def TemperatureSensor {
        port sensorOut : SensorOutputPort;
        
        attribute currentTemp : ISQ::ThermodynamicTemperatureValue = 310.0 [SI::K];
        attribute maxSafeTemp : ISQ::ThermodynamicTemperatureValue = 318.0 [SI::K];
    }
    
    part def AmbientLightSensor {
        port sensorOut : SensorOutputPort;
        
        attribute detectedLevel : IlluminanceLevel = 500.0 [SI::lx];
    }
    
    part def SterileHandle {
        attribute isAutoclavable : Boolean = true;
        attribute handleDiameter : ISQ::LengthValue = 35.0 [SI::mm];
        attribute gripMaterial : String = "Medical Grade Silicone";
    }
    
    action def GenerateLight {
        in powerLevel : ISQ::PowerValue;
        in targetIntensity : IntensityPercent;
        out outputIlluminance : IlluminanceLevel;
        
        first start;
        then action calculateOutput {
            assign outputIlluminance := (targetIntensity / 100.0) * 160000.0 [SI::lx];
        }
        then done;
    }
    
    action def AdjustIntensity {
        in currentLevel : IntensityPercent;
        in commandedLevel : IntensityPercent;
        out newLevel : IntensityPercent;
        
        first start;
        then decide;
            if commandedLevel > currentLevel then increase;
            if commandedLevel < currentLevel then decrease;
            if commandedLevel == currentLevel then maintain;
        
        action increase {
            assign newLevel := commandedLevel;
        }
        action decrease {
            assign newLevel := commandedLevel;
        }
        action maintain {
            assign newLevel := currentLevel;
        }
        then done;
    }
    
    action def MonitorThermalConditions {
        in temperature : ISQ::ThermodynamicTemperatureValue;
        in maxTemp : ISQ::ThermodynamicTemperatureValue;
        out fanSpeedAdjustment : Real;
        
        first start;
        then decide;
            if temperature > maxTemp then activateCooling;
            if temperature <= maxTemp then normalCooling;
        
        action activateCooling {
            assign fanSpeedAdjustment := 100.0;
        }
        action normalCooling {
            assign fanSpeedAdjustment := 60.0;
        }
        then done;
    }
    
    action def PositionLightHead {
        in targetPosition : PositionCommand;
        in currentPosition : PositionCommand;
        out armMovement : Boolean;
        
        first start;
        then action moveArm {
            assign armMovement := true;
        }
        then done;
    }
    
    action def ProvideSurgicalIllumination {
        in powerCmd : PowerCommand;
        in intensityCmd : IntensityCommand;
        in positionCmd : PositionCommand;
        in ambientLight : IlluminanceLevel;
        out deliveredLight : LightOutput;
        
        private attribute currentIntensityLevel : IntensityPercent := 80.0;
        
        first start;
        then merge operationLoop;
        
        then decide;
            if powerCmd.isOn == false then shutDownAction;
            if powerCmd.isOn == true then operateAction;
        
        action operateAction {
            first action adjustIntensityAction : AdjustIntensity {
                in currentLevel = currentIntensityLevel;
                in commandedLevel = intensityCmd.level;
                out newLevel;
            }
            then assign currentIntensityLevel := adjustIntensityAction.newLevel;
            
            then action generateLightAction : GenerateLight {
                in powerLevel : ISQ::PowerValue = 180.0 [SI::W];
                in targetIntensity = currentIntensityLevel;
                out outputIlluminance;
            }
            
            then action positionHead : PositionLightHead {
                in targetPosition = positionCmd;
                in currentPosition : PositionCommand;
                out armMovement;
            }
            
            then action monitorThermal : MonitorThermalConditions {
                in temperature : ISQ::ThermodynamicTemperatureValue = 315.0 [SI::K];
                in maxTemp : ISQ::ThermodynamicTemperatureValue = 318.0 [SI::K];
                out fanSpeedAdjustment;
            }
            
            then assign deliveredLight.illuminance := generateLightAction.outputIlluminance;
            then assign deliveredLight.colorTemp := 4500.0 [SI::K];
            then assign deliveredLight.beamDiameter := 200.0 [SI::mm];
        }
        
        action shutDownAction {
            assign deliveredLight.illuminance := 0.0 [SI::lx];
            assign deliveredLight.colorTemp := 0.0 [SI::K];
            assign deliveredLight.beamDiameter := 0.0 [SI::mm];
        }
        
        then operationLoop;
    }
    
    state def LightingSystemStates {
        entry; then powerOff;
        
        state powerOff {
            entry assign systemIlluminance := 0.0 [SI::lx];
        }
        
        transition powerOff_to_standby
            first powerOff
            accept PowerOnCommand
            then standby;
        
        state standby {
            entry assign systemIlluminance := 5000.0 [SI::lx];
            entry assign systemColorTemp := 4000.0 [SI::K];
        }
        
        transition standby_to_surgical
            first standby
            accept ActivateSurgicalMode
            then surgicalMode;
        
        transition standby_to_examination
            first standby
            accept ActivateExaminationMode
            then examinationMode;
        
        state surgicalMode {
            entry assign systemIlluminance := 160000.0 [SI::lx];
            entry assign systemColorTemp := 4500.0 [SI::K];
            entry assign systemBeamDiameter := 200.0 [SI::mm];
            
            do action provideSurgicalLight : ProvideSurgicalIllumination;
        }
        
        state examinationMode {
            entry assign systemIlluminance := 40000.0 [SI::lx];
            entry assign systemColorTemp := 4000.0 [SI::K];
            entry assign systemBeamDiameter := 250.0 [SI::mm];
        }
        
        state endoscopyMode {
            entry assign systemIlluminance := 80000.0 [SI::lx];
            entry assign systemColorTemp := 5500.0 [SI::K];
            entry assign systemBeamDiameter := 150.0 [SI::mm];
        }
        
        transition surgical_to_standby
            first surgicalMode
            accept DeactivateCommand
            then standby;
        
        transition examination_to_standby
            first examinationMode
            accept DeactivateCommand
            then standby;
        
        transition endoscopy_to_standby
            first endoscopyMode
            accept DeactivateCommand
            then standby;
        
        transition standby_to_endoscopy
            first standby
            accept ActivateEndoscopyMode
            then endoscopyMode;
        
        transition standby_to_powerOff
            first standby
            accept PowerOffCommand
            then powerOff;
        
        transition emergency_shutdown
            accept EmergencyShutdown
            then powerOff;
    }
    
    part def SurgicalLightingSystem;
    
    part surgicalLightingSystem : SurgicalLightingSystem {
        doc /* A complete surgical lighting system designed to provide high-intensity,
               shadow-free, color-accurate illumination of the surgical field. The system
               enables precise visualization of anatomical structures and surgical procedures
               through adjustable, focused lighting with minimal heat generation. */
        
        attribute operatingVoltage : ISQ::ElectricPotentialValue = 230.0 [SI::V];
        attribute maxPowerConsumption : ISQ::PowerValue = 200.0 [SI::W];
        attribute illuminanceRange : IlluminanceLevel[2] = (10000.0 [SI::lx], 160000.0 [SI::lx]);
        attribute colorTempRange : ColorTemperature[2] = (3500.0 [SI::K], 5500.0 [SI::K]);
        
        part powerSupply : PowerSupply;
        
        part ledModule : LEDModule {
            attribute :>> numberOfLEDs = 60;
            attribute :>> maxLuminousFlux = 30000.0 [SI::lm];
        }
        
        part opticalAssembly : OpticalAssembly {
            attribute :>> lensCount = 4;
            attribute :>> beamAngle = 20.0 [SI::'°'];
        }
        
        part coolingFan : CoolingFan {
            attribute :>> fanSpeed = 2500.0;
            attribute :>> maxHeatDissipation = 160.0 [SI::W];
        }
        
        part controlUnit : ControlUnit {
            perform action systemOperation : ProvideSurgicalIllumination;
            exhibit state systemBehavior : LightingSystemStates;
        }
        
        part articulatingArm : ArticulatingArm {
            attribute :>> numberOfJoints = 5;
            attribute :>> maxReach = 2.0 [SI::m];
            attribute :>> lockingEnabled = true;
        }
        
        part tempSensor : TemperatureSensor {
            attribute :>> maxSafeTemp = 318.0 [SI::K];
        }
        
        part ambientSensor : AmbientLightSensor;
        
        part sterileHandle : SterileHandle {
            attribute :>> isAutoclavable = true;
        }
        
        connection powerFlow connect powerSupply.dcOutput to ledModule.powerIn;
        connection powerToFan connect powerSupply.dcOutput to coolingFan.powerIn;
        connection lightPath connect ledModule.lightOut to opticalAssembly.lightIn;
        connection tempMonitoring connect tempSensor.sensorOut to controlUnit.sensorIn;
        connection ambientMonitoring connect ambientSensor.sensorOut to controlUnit.sensorIn;
        connection ledPowerControl connect controlUnit.ledControl to ledModule.powerIn;
        connection fanPowerControl connect controlUnit.fanControl to coolingFan.powerIn;
    }
    
    requirement def IlluminanceCapability {
        doc /* The surgical lighting system shall provide adjustable illuminance
               from 10,000 lux to 160,000 lux at the surgical field center. */
        
        subject system : SurgicalLightingSystem;
        
        require constraint {
            system.illuminanceRange[1] >= 10000.0 [SI::lx] and
            system.illuminanceRange[2] <= 160000.0 [SI::lx]
        }
    }
    
    requirement def ColorAccuracy {
        doc /* The system shall maintain a color rendering index (CRI) of at least 95
               to ensure accurate tissue color representation during surgery. */
        
        subject system : SurgicalLightingSystem;
        
        attribute minimumCRI : Real = 95.0;
    }
    
    requirement def ShadowReduction {
        doc /* The lighting system shall reduce shadows by at least 90% through
               multi-LED configuration and optical design. */
        
        subject system : SurgicalLightingSystem;
        
        attribute minimumShadowReduction : Real = 0.90;
    }
    
    requirement def ThermalSafety {
        doc /* The light head surface temperature shall not exceed 45°C (318K)
               during continuous operation to prevent thermal injury. */
        
        subject sensor : TemperatureSensor;
        
        require constraint {
            sensor.currentTemp <= sensor.maxSafeTemp
        }
    }
    
    requirement def SterilityMaintenance {
        doc /* All components within the sterile field shall be autoclavable
               and maintain sterility during surgical procedures. */
        
        subject handle : SterileHandle;
        
        require constraint {
            handle.isAutoclavable == true
        }
    }
    
    requirement def PositioningFlexibility {
        doc /* The articulating arm shall provide at least 2 meters of reach
               with stable positioning and friction locking capability. */
        
        subject arm : ArticulatingArm;
        
        require constraint {
            arm.maxReach >= 2.0 [SI::m] and
            arm.lockingEnabled == true
        }
    }
    
    requirement <'SLS-REQ-001'> primaryMissionRequirement {
        doc /* The surgical lighting system shall provide high-intensity, shadow-free,
               color-accurate illumination of the surgical field to enable precise
               visualization of anatomical structures and surgical procedures while
               maintaining thermal safety and sterility standards. */
        
        assume constraint operatingEnvironment {
            doc /* The system operates in a controlled operating room environment
                   with regulated temperature and ambient lighting. */
        }
        
        require illuminanceReq : IlluminanceCapability;
        require colorReq : ColorAccuracy;
        require shadowReq : ShadowReduction;
        require thermalReq : ThermalSafety;
        require sterileReq : SterilityMaintenance;
        require positionReq : PositioningFlexibility;
    }
    
    satisfy primaryMissionRequirement by surgicalLightingSystem;
}
