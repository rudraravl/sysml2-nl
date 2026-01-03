package 'Dental Handpiece System' {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    
    attribute def RotationalSpeedValue :> AngularVelocityValue {
        attribute :>> num : Real;
        attribute :>> mRef : AngularVelocityUnit;
    }
    
    attribute def FlowRateValue :> VolumeFlowRateValue {
        attribute :>> num : Real;
        attribute :>> mRef : VolumeFlowRateUnit;
    }
    
    attribute def PressureValue :> ISQ::PressureValue {
        attribute :>> num : Real;
        attribute :>> mRef : PressureUnit;
    }
    
    attribute def TemperatureValue :> ThermodynamicTemperatureValue {
        attribute :>> num : Real;
        attribute :>> mRef : ThermodynamicTemperatureUnit;
    }
    
    item def CompressedAir {
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }
    
    item def CoolingWater {
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
        attribute temperature : TemperatureValue;
    }
    
    item def MechanicalPower {
        attribute torque : TorqueValue;
        attribute speed : RotationalSpeedValue;
    }
    
    attribute def PedalPosition :> Real;
    attribute def OperatingModeType;
    
    enum def OperatingMode :> OperatingModeType {
        lowSpeed;
        highSpeed;
        idle;
    }
    
    port def AirInputPort {
        in item airSupply : CompressedAir;
    }
    
    port def WaterInputPort {
        in item waterSupply : CoolingWater;
    }
    
    port def MechanicalOutputPort {
        out item mechanicalOutput : MechanicalPower;
    }
    
    port def CoolingOutputPort {
        out item coolingOutput : CoolingWater;
    }
    
    port def ControlInputPort {
        in attribute pedalInput : PedalPosition;
        in attribute modeSelect : OperatingMode;
    }
    
    part def AirTurbine {
        attribute maxSpeed : RotationalSpeedValue;
        attribute currentSpeed : RotationalSpeedValue;
        port airIn : AirInputPort;
        port driveOut : MechanicalOutputPort;
        
        action generateRotation {
            in airPressure : PressureValue;
            out outputSpeed : RotationalSpeedValue;
            out outputTorque : TorqueValue;
        }
    }
    
    part def WaterDeliverySystem {
        attribute nominalFlow : FlowRateValue;
        attribute currentFlow : FlowRateValue;
        port waterIn : WaterInputPort;
        port coolingOut : CoolingOutputPort;
        
        action deliverCoolant {
            in waterPressure : PressureValue;
            in flowControl : Real;
            out coolingFlow : FlowRateValue;
        }
    }
    
    part def ControlModule {
        attribute currentMode : OperatingMode;
        attribute speedSetpoint : RotationalSpeedValue;
        port controlIn : ControlInputPort;
        
        action processInput {
            in pedalPosition : PedalPosition;
            in mode : OperatingMode;
            out targetSpeed : RotationalSpeedValue;
            out waterFlowCommand : Real;
        }
    }
    
    part def BearingAssembly {
        attribute maxLoad : ForceValue;
        port mechanicalIn : MechanicalOutputPort;
        port mechanicalOut : MechanicalOutputPort;
        
        action transmitPower {
            in inputTorque : TorqueValue;
            in inputSpeed : RotationalSpeedValue;
            out outputTorque : TorqueValue;
            out outputSpeed : RotationalSpeedValue;
        }
    }
    
    part def BurrChuck {
        attribute grippingForce : ForceValue;
        attribute burrDiameter : LengthValue;
        port driveIn : MechanicalOutputPort;
        port coolingIn : CoolingOutputPort;
        
        action performCutting {
            in driveTorque : TorqueValue;
            in driveSpeed : RotationalSpeedValue;
            in coolingFlow : FlowRateValue;
            out cuttingEfficiency : Real;
        }
    }
    
    part def FootPedal {
        attribute position : PedalPosition;
        attribute sensitivity : Real;
        
        action detectInput {
            out pedalPosition : PedalPosition;
        }
    }
    
    part def DentalHandpiece {
        part turbine : AirTurbine {
            attribute :>> maxSpeed = RotationalSpeedValue(num = 400000.0, mRef = rpm);
        }
        
        part waterSystem : WaterDeliverySystem {
            attribute :>> nominalFlow = FlowRateValue(num = 50.0, mRef = mL/min);
        }
        
        part controller : ControlModule {
            attribute :>> currentMode = OperatingMode::idle;
        }
        
        part bearings : BearingAssembly {
            attribute :>> maxLoad = ForceValue(num = 50.0, mRef = N);
        }
        
        part chuck : BurrChuck {
            attribute :>> burrDiameter = LengthValue(num = 1.6, mRef = mm);
        }
        
        part pedal : FootPedal {
            attribute :>> sensitivity = 0.8;
        }
        
        port airSupplyPort : AirInputPort;
        port waterSupplyPort : WaterInputPort;
        port pedalInputPort : ControlInputPort;
        
        connect airSupplyPort to turbine.airIn;
        connect waterSupplyPort to waterSystem.waterIn;
        connect pedalInputPort to controller.controlIn;
        connect turbine.driveOut to bearings.mechanicalIn;
        connect bearings.mechanicalOut to chuck.driveIn;
        connect waterSystem.coolingOut to chuck.coolingIn;
        
        perform action operateHandpiece : OperateHandpiece;
    }
    
    action def MonitorPedalPosition {
        in pedalSensor : PedalPosition;
        out currentPosition : PedalPosition;
    }
    
    action def DetermineOperatingMode {
        in pedalPosition : PedalPosition;
        out selectedMode : OperatingMode;
        out targetSpeed : RotationalSpeedValue;
    }
    
    action def RegulateAirFlow {
        in targetSpeed : RotationalSpeedValue;
        in airPressure : PressureValue;
        out regulatedPressure : PressureValue;
    }
    
    action def ActivateCooling {
        in operatingSpeed : RotationalSpeedValue;
        in waterPressure : PressureValue;
        out coolingFlowRate : FlowRateValue;
    }
    
    action def DriveRotation {
        in airPressure : PressureValue;
        out rotationalSpeed : RotationalSpeedValue;
        out torque : TorqueValue;
    }
    
    action def PerformDentalProcedure {
        in rotationalSpeed : RotationalSpeedValue;
        in torque : TorqueValue;
        in coolingFlow : FlowRateValue;
        out materialRemovalRate : Real;
    }
    
    action def OperateHandpiece {
        in airSupply : CompressedAir;
        in waterSupply : CoolingWater;
        in pedalInput : PedalPosition;
        out procedureComplete : Boolean;
        
        first start;
        
        then merge operationCycle;
        
        then action monitorPedal : MonitorPedalPosition {
            in pedalSensor = pedalInput;
            out currentPosition : PedalPosition;
        }
        
        then action determineMode : DetermineOperatingMode {
            in pedalPosition = monitorPedal.currentPosition;
            out selectedMode : OperatingMode;
            out targetSpeed : RotationalSpeedValue;
        }
        
        then decide;
            if determineMode.selectedMode == OperatingMode::idle then shutdown;
            if determineMode.selectedMode != OperatingMode::idle then regulate;
        
        action regulate : RegulateAirFlow {
            in targetSpeed = determineMode.targetSpeed;
            in airPressure = airSupply.pressure;
            out regulatedPressure : PressureValue;
        }
        
        then action activateCooling : ActivateCooling {
            in operatingSpeed = determineMode.targetSpeed;
            in waterPressure = waterSupply.pressure;
            out coolingFlowRate : FlowRateValue;
        }
        
        then action driveRotation : DriveRotation {
            in airPressure = regulate.regulatedPressure;
            out rotationalSpeed : RotationalSpeedValue;
            out torque : TorqueValue;
        }
        
        then action performProcedure : PerformDentalProcedure {
            in rotationalSpeed = driveRotation.rotationalSpeed;
            in torque = driveRotation.torque;
            in coolingFlow = activateCooling.coolingFlowRate;
            out materialRemovalRate : Real;
        }
        
        then operationCycle;
        
        action shutdown {
            assign procedureComplete := true;
        }
        
        then done;
    }
    
    state def HandpieceOperatingStates {
        entry; then standby;
        
        state standby;
        
        transition standby_to_startup
            first standby
            accept pedalEngaged
            then startup;
        
        state startup;
        
        transition startup_to_operating
            first startup
            then operating;
        
        state operating;
        
        transition operating_to_shutdown
            first operating
            accept pedalReleased
            then shutdown;
        
        state shutdown;
        
        transition shutdown_to_standby
            first shutdown
            then standby;
        
        state alarm;
        
        transition alarm_to_standby
            first alarm
            then standby;
    }
    
    requirement <'DH-001'> primaryFunctionRequirement {
        doc /* The dental handpiece system shall provide controlled high-speed rotation 
             for precise removal of tooth material during dental procedures, with 
             integrated water cooling to prevent thermal damage to dental tissues. */
        
        subject handpiece : DentalHandpiece;
        
        require speedControlRequirement;
        require coolingRequirement;
        require safetyRequirement;
    }
    
    requirement <'DH-002'> speedControlRequirement {
        doc /* The system shall provide variable speed control from 0 to 400,000 RPM 
             based on foot pedal position with smooth acceleration and deceleration. */
        
        assume constraint pedalRange {
            0.0 <= handpiece.pedal.position and handpiece.pedal.position <= 1.0
        }
        
        require constraint speedRange {
            handpiece.turbine.currentSpeed.num >= 0.0 and
            handpiece.turbine.currentSpeed.num <= handpiece.turbine.maxSpeed.num
        }
        
        require constraint speedResponse {
            handpiece.turbine.currentSpeed.num == 
                handpiece.pedal.position * handpiece.turbine.maxSpeed.num
        }
    }
    
    requirement <'DH-003'> coolingRequirement {
        doc /* The system shall deliver continuous water cooling at minimum 50 mL/min 
             whenever rotational speed exceeds 10,000 RPM to prevent thermal damage. */
        
        require constraint coolingActivation {
            handpiece.turbine.currentSpeed.num > 10000.0 implies
            handpiece.waterSystem.currentFlow.num >= 50.0
        }
        
        require constraint coolingTemperature {
            handpiece.waterSystem.waterIn.waterSupply.temperature.num >= 15.0 and
            handpiece.waterSystem.waterIn.waterSupply.temperature.num <= 25.0
        }
    }
    
    requirement <'DH-004'> safetyRequirement {
        doc /* The system shall cease rotation within 3 seconds of foot pedal release 
             and prevent operation if cooling water supply is insufficient. */
        
        require constraint emergencyStop {
            handpiece.pedal.position == 0.0 implies
            handpiece.turbine.currentSpeed.num <= 1000.0
        }
        
        require constraint waterInterlock {
            handpiece.waterSystem.waterIn.waterSupply.pressure.num < 200.0 implies
            handpiece.turbine.currentSpeed.num == 0.0
        }
    }
    
    requirement <'DH-005'> performanceRequirement {
        doc /* The system shall maintain consistent torque delivery and minimize 
             vibration during operation for precise material removal. */
        
        require constraint torqueStability {
            handpiece.turbine.driveOut.mechanicalOutput.torque.num >= 0.02 and
            handpiece.turbine.driveOut.mechanicalOutput.torque.num <= 0.05
        }
    }
}
