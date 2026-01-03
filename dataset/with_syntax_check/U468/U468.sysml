package ArtificialLiftSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def FlowRate :> ISQ::VolumeFlowRateValue;
    attribute def WellDepth :> ISQ::LengthValue;
    attribute def FluidDensity :> ISQ::DensityValue;
    attribute def FluidViscosity :> ISQ::DynamicViscosityValue;
    
    item def WellFluid {
        attribute density : FluidDensity;
        attribute viscosity : FluidViscosity;
        attribute temperature : ISQ::ThermodynamicTemperatureValue;
        attribute gasOilRatio : Real;
    }
    
    item def ControlCommand {
        attribute speedSetpoint : ISQ::AngularVelocityValue;
        attribute pressureSetpoint : ISQ::PressureValue;
    }
    
    item def SensorData {
        attribute bottomholePressure : ISQ::PressureValue;
        attribute flowRate : FlowRate;
        attribute motorTemperature : ISQ::ThermodynamicTemperatureValue;
        attribute vibrationLevel : ISQ::AccelerationValue;
    }
    
    item def StartCommand;
    item def StopCommand;
    item def ResetCommand;
    
    port def FluidPort {
        attribute pressure : ISQ::PressureValue;
        attribute flowRate : FlowRate;
    }
    
    port def PowerPort {
        attribute voltage : ISQ::ElectricPotentialValue;
        attribute current : ISQ::ElectricCurrentValue;
        attribute frequency : ISQ::FrequencyValue;
    }
    
    port def ControlPort {
        in item command : ControlCommand;
    }
    
    port def SensorPort {
        out item data : SensorData;
    }
    
    part def Reservoir {
        attribute reservoirPressure : ISQ::PressureValue;
        attribute fluidLevel : ISQ::LengthValue;
        attribute permeability : Real;
        port fluidOutput : FluidPort;
    }
    
    part def ElectricSubmersiblePump {
        attribute ratedSpeed : ISQ::AngularVelocityValue;
        attribute stages : Integer;
        attribute efficiency : Real;
        attribute speedReached : Boolean;
        attribute speedZero : Boolean;
        attribute overTemperature : Boolean;
        attribute lowPressure : Boolean;
        
        port fluidInlet : FluidPort;
        port fluidOutlet : FluidPort;
        port driveInput : PowerPort;
        
        state pumpStates {
            entry; then idle;
            state idle;
            state starting;
            state running;
            state stopping;
            state fault;
            
            transition idle_to_starting
                first idle
                accept at startTime StartCommand
                then starting;
            
            transition starting_to_running
                first starting
                if speedReached
                then running;
            
            transition running_to_stopping
                first running
                accept at stopTime StopCommand
                then stopping;
            
            transition running_to_fault
                first running
                if overTemperature or lowPressure
                then fault;
            
            transition stopping_to_idle
                first stopping
                if speedZero
                then idle;
            
            transition fault_to_idle
                first fault
                accept at resetTime ResetCommand
                then idle;
        }
    }
    
    part def DownholeMotor {
        attribute ratedPower : ISQ::PowerValue;
        attribute operatingTemperature : ISQ::ThermodynamicTemperatureValue;
        attribute maxTemperature : ISQ::ThermodynamicTemperatureValue;
        port powerInput : PowerPort;
        port mechanicalOutput : ~PowerPort;
        port sensors : SensorPort;
    }
    
    part def ProductionTubing {
        attribute length : WellDepth;
        attribute innerDiameter : ISQ::LengthValue;
        attribute roughness : ISQ::LengthValue;
        port inlet : FluidPort;
        port outlet : FluidPort;
    }
    
    part def VariableFrequencyDrive {
        attribute outputFrequency : ISQ::FrequencyValue;
        attribute outputVoltage : ISQ::ElectricPotentialValue;
        port gridPowerIn : PowerPort;
        port motorPowerOut : PowerPort;
        port controlIn : ControlPort;
    }
    
    part def SurfaceController {
        attribute targetFlowRate : FlowRate;
        attribute targetPressure : ISQ::PressureValue;
        attribute minBottomholePressure : ISQ::PressureValue;
        port sensorDataIn : SensorPort;
        port commandOut : ControlPort;
        
        perform action controlLoop;
    }
    
    part def FlowMeter {
        attribute accuracy : Real;
        attribute measuredFlowRate : FlowRate;
        port fluidMeasurement : FluidPort;
        port dataOut : SensorPort;
    }
    
    part def PressureSensor {
        attribute range : ISQ::PressureValue;
        attribute measuredPressure : ISQ::PressureValue;
        port pressureMeasurement : FluidPort;
        port dataOut : SensorPort;
    }
    
    part def SurfaceSeparator {
        attribute separationEfficiency : Real;
        port fluidInlet : FluidPort;
        port oilOutlet : FluidPort;
        port gasOutlet : FluidPort;
        port waterOutlet : FluidPort;
    }
    
    action def MonitorWellConditions {
        in sensorData : SensorData;
        in targetPressure : ISQ::PressureValue;
        in targetFlow : FlowRate;
        out pressureDeviation : Real;
        out flowDeviation : Real;
    }
    
    action def CalculateSpeedAdjustment {
        in pressureDeviation : Real;
        in flowDeviation : Real;
        in currentSpeed : ISQ::AngularVelocityValue;
        out newSpeed : ISQ::AngularVelocityValue;
    }
    
    action def IssueControlCommand {
        in speedSetpoint : ISQ::AngularVelocityValue;
        in pressureSetpoint : ISQ::PressureValue;
        out command : ControlCommand;
    }
    
    action def CheckSafetyLimits {
        in sensorData : SensorData;
        in maxTemperature : ISQ::ThermodynamicTemperatureValue;
        in minPressure : ISQ::PressureValue;
        out safetyStatus : Boolean;
    }
    
    action def LiftFluidToSurface {
        in targetFlowRate : FlowRate;
        in targetPressure : ISQ::PressureValue;
        in minBottomholePressure : ISQ::PressureValue;
        in maxMotorTemperature : ISQ::ThermodynamicTemperatureValue;
        
        private attribute currentSpeed : ISQ::AngularVelocityValue := 0.0 [SI::'rad/s'];
        private attribute safeToOperate : Boolean := true;
        
        first start;
        then merge continuousOperation;
        
        then action monitor : MonitorWellConditions {
            in sensorData;
            in targetPressure = targetPressure;
            in targetFlow = targetFlowRate;
            out pressureDeviation;
            out flowDeviation;
        }
        
        then action checkSafety : CheckSafetyLimits {
            in sensorData;
            in maxTemperature = maxMotorTemperature;
            in minPressure = minBottomholePressure;
            out safetyStatus;
        }
        
        then assign safeToOperate := checkSafety.safetyStatus;
        
        then decide;
            if not safeToOperate then emergencyShutdown;
            if safeToOperate and (monitor.pressureDeviation > 0.1 or monitor.flowDeviation > 0.1) then adjustOperation;
            else maintainOperation;
        
        action emergencyShutdown {
            out shutdownCommand : ControlCommand = ControlCommand {
                speedSetpoint = 0.0 [SI::'rad/s'];
                pressureSetpoint = 0.0 [SI::Pa];
            }
        }
        then done;
        
        action adjustOperation : CalculateSpeedAdjustment {
            in pressureDeviation = monitor.pressureDeviation;
            in flowDeviation = monitor.flowDeviation;
            in currentSpeed = currentSpeed;
            out newSpeed;
        }
        then assign currentSpeed := adjustOperation.newSpeed;
        then issueAdjustedCommand;
        
        action maintainOperation {
            out maintainSpeed : ISQ::AngularVelocityValue = currentSpeed;
        }
        then issueAdjustedCommand;
        
        action issueAdjustedCommand : IssueControlCommand {
            in speedSetpoint = currentSpeed;
            in pressureSetpoint = targetPressure;
            out command;
        }
        then continuousOperation;
    }
    
    part espLiftSystem {
        attribute systemTargetFlowRate : FlowRate = 150.0 [SI::L/SI::s];
        attribute systemTargetPressure : ISQ::PressureValue = 2000.0 [SI::kPa];
        
        part reservoir : Reservoir {
            attribute :>> reservoirPressure = 5000.0 [SI::kPa];
            attribute :>> fluidLevel = 800.0 [SI::m];
            attribute :>> permeability = 0.5;
        }
        
        part downholePump : ElectricSubmersiblePump {
            attribute :>> ratedSpeed = 3600.0 [SI::'rad/s'];
            attribute :>> stages = 120;
            attribute :>> efficiency = 0.68;
        }
        
        part pumpMotor : DownholeMotor {
            attribute :>> ratedPower = 75000.0 [SI::W];
            attribute :>> operatingTemperature = 373.15 [SI::K];
            attribute :>> maxTemperature = 423.15 [SI::K];
        }
        
        part tubing : ProductionTubing {
            attribute :>> length = 1200.0 [SI::m];
            attribute :>> innerDiameter = 0.0762 [SI::m];
            attribute :>> roughness = 0.000046 [SI::m];
        }
        
        part vfd : VariableFrequencyDrive {
            attribute :>> outputFrequency = 60.0 [SI::Hz];
            attribute :>> outputVoltage = 480.0 [SI::V];
        }
        
        part controller : SurfaceController {
            attribute :>> targetFlowRate = espLiftSystem.systemTargetFlowRate;
            attribute :>> targetPressure = espLiftSystem.systemTargetPressure;
            attribute :>> minBottomholePressure = 1000.0 [SI::kPa];
            
            perform action :>> controlLoop references liftOperation;
        }
        
        part flowMeter : FlowMeter {
            attribute :>> accuracy = 0.98;
        }
        
        part pressureSensor : PressureSensor {
            attribute :>> range = 10000.0 [SI::kPa];
        }
        
        part separator : SurfaceSeparator {
            attribute :>> separationEfficiency = 0.95;
        }
        
        perform action liftOperation : LiftFluidToSurface[*] ordered {
            in targetFlowRate = controller.targetFlowRate;
            in targetPressure = controller.targetPressure;
            in minBottomholePressure = controller.minBottomholePressure;
            in maxMotorTemperature = pumpMotor.maxTemperature;
        }
        
        connection reservoirToDownhole connect reservoir.fluidOutput to downholePump.fluidInlet;
        connection pumpToTubing connect downholePump.fluidOutlet to tubing.inlet;
        connection tubingToSeparator connect tubing.outlet to separator.fluidInlet;
        connection motorToPump connect pumpMotor.mechanicalOutput to downholePump.driveInput;
        connection vfdToMotor connect vfd.motorPowerOut to pumpMotor.powerInput;
        connection controllerToVfd connect controller.commandOut to vfd.controlIn;
        connection sensorToController connect pumpMotor.sensors to controller.sensorDataIn;
        connection flowMeterConnection connect tubing.outlet to flowMeter.fluidMeasurement;
        connection pressureSensorConnection connect downholePump.fluidInlet to pressureSensor.pressureMeasurement;
    }
    
    requirement def SystemRequirement;
    requirement def PerformanceRequirement :> SystemRequirement;
    requirement def SafetyRequirement :> SystemRequirement;
    
    requirement <'ALR-001'> primaryLiftFunction : SystemRequirement {
        doc /* The artificial lift system shall extract fluid from the subsurface reservoir 
                and deliver it to the surface separator by applying mechanical energy to 
                overcome the pressure differential and gravitational head. */
    }
    
    requirement <'ALR-002'> flowRateRequirement : PerformanceRequirement {
        doc /* The system shall maintain production flow rate within 5% of the target 
                flow rate under normal operating conditions. */
        
        require constraint flowRateConstraint {
            espLiftSystem.flowMeter.measuredFlowRate >= 
                espLiftSystem.systemTargetFlowRate * 0.95 and
            espLiftSystem.flowMeter.measuredFlowRate <= 
                espLiftSystem.systemTargetFlowRate * 1.05
        }
    }
    
    requirement <'ALR-003'> pressureMaintenanceRequirement : PerformanceRequirement {
        doc /* The system shall maintain bottomhole pressure above the minimum threshold 
                to prevent formation damage and ensure reservoir integrity. */
        
        require constraint pressureConstraint {
            espLiftSystem.pressureSensor.measuredPressure >= 
                espLiftSystem.controller.minBottomholePressure
        }
    }
    
    requirement <'ALR-004'> motorProtectionRequirement : SafetyRequirement {
        doc /* The system shall automatically shut down the pump motor if operating 
                temperature exceeds the maximum rated temperature to prevent equipment damage. */
        
        require constraint temperatureConstraint {
            espLiftSystem.pumpMotor.operatingTemperature < 
                espLiftSystem.pumpMotor.maxTemperature
        }
    }
    
    requirement <'ALR-005'> continuousOperationRequirement : SystemRequirement {
        doc /* The system shall continuously monitor well conditions and automatically 
                adjust pump speed to optimize production while maintaining safe operating limits. */
        
        require primaryLiftFunction;
        require flowRateRequirement;
        require pressureMaintenanceRequirement;
        require motorProtectionRequirement;
    }
}
