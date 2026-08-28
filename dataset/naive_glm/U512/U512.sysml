package CoolingCirculationSystem {
    import ScalarValues::*;
    import ISQ::*;
    
    // ===== Value Types with Units =====
    
    value type PressureValue > Real {
        unit Pa;
    }
    
    value type FlowRateValue > Real {
        unit 'm3/s';
    }
    
    value type TemperatureValue > Real {
        unit K;
    }
    
    value type RotationalSpeedValue > Real {
        unit 'rad/s';
    }
    
    value type PowerValue > Real {
        unit W;
    }
    
    value type VolumeValue > Real {
        unit 'm3';
    }
    
    value type FractionValue > Real {
        unit '1';
    }
    
    value type VoltageValue > Real {
        unit V;
    }
    
    value type CurrentValue > Real {
        unit A;
    }
    
    // ===== Item Types =====
    
    item def WaterGlycolMixture {
        attribute glycolFraction : FractionValue = 0.4;
        attribute specificHeat : Real = 3.5e3 [J/(kg*K)];
        attribute density : Real = 1050 [kg/m3];
    }
    
    item def CoolingFluid :> WaterGlycolMixture {
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
    }
    
    // ===== Port Definitions =====
    
    port def FluidPort {
        in item fluidIn : CoolingFluid;
        out item fluidOut : CoolingFluid;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
        attribute temperature : TemperatureValue;
    }
    
    port def ElectricalPort {
        in voltage : VoltageValue;
        out current : CurrentValue;
    }
    
    port def ControlSignalPort {
        in command : ControlCommand;
        out feedback : SensorFeedback;
    }
    
    // ===== Control and Feedback Item Definitions =====
    
    item def ControlCommand {
        attribute targetFlowRate : FlowRateValue;
        attribute operatingMode : OperatingMode;
    }
    
    enumeration def OperatingMode {
        NORMAL;
        HIGH_DEMAND;
        LOW_DEMAND;
        SHUTDOWN;
    }
    
    item def SensorFeedback {
        attribute measuredFlowRate : FlowRateValue;
        attribute measuredPressure : PressureValue;
        attribute measuredTemperature : TemperatureValue;
        attribute cavitationDetected : Boolean;
        attribute faultActive : Boolean;
    }
    
    // ===== Requirements =====
    
    requirement def ClosedLoopOperationRequirement {
        doc /* The system shall circulate water-glycol mixture continuously in a closed loop. */
        subject system : CoolingCirculationSystem;
        attribute minContinuousOperationHours : Real = 8760 [h];
        require system.reservoir.fluidVolume >= 0.05 [m3];
        require system.heatExchanger.thermalDuty >= 50e3 [W];
    }
    
    requirement def LeakPreventionRequirement {
        doc /* The pump shall be glandless/sealless using magnetic bearings to prevent fluid leakage. */
        subject pump : CirculatingPump;
        require pump.bearingAssembly.bearingType == BearingType::MAGNETIC;
        require pump.sealCount == 0;
    }
    
    requirement def FlowControlRequirement {
        doc /* The controller shall adjust motor speed to meet flow rate demands in normal, high-demand, and low-demand modes. */
        subject controller : PumpController;
        require controller.supportedModes == {OperatingMode::NORMAL, OperatingMode::HIGH_DEMAND, OperatingMode::LOW_DEMAND};
        require controller.tolerance <= 0.05 [m3/s];
    }
    
    requirement def FaultProtectionRequirement {
        doc /* The system shall detect cavitation and initiate safe shutdown to protect equipment. */
        subject system : CoolingCirculationSystem;
        require system.controller.cavitationResponseTime <= 2 [s];
        require system.controller.faultHandlingEnabled == true;
    }
    
    requirement def MonitoringRequirement {
        doc /* The system shall measure flow rate, pressure, and temperature for real-time feedback. */
        subject system : CoolingCirculationSystem;
        require system.flowSensor.measurementRange >= 0.5 [m3/s];
        require system.pressureSensor.measurementRange >= 1e6 [Pa];
        require system.temperatureSensor.measurementRange >= 100 [K];
    }
    
    // ===== Enumerations =====
    
    enumeration def BearingType {
        MAGNETIC;
        MECHANICAL;
        HYDRODYNAMIC;
    }
    
    enumeration def PumpState {
        IDLE;
        PRIMING;
        NORMAL_CIRCULATION;
        HIGH_DEMAND_CIRCULATION;
        LOW_DEMAND_CIRCULATION;
        SAFE_SHUTDOWN;
        FAULT;
    }
    
    enumeration def FaultType {
        NONE;
        CAVITATION;
        OVERTEMPERATURE;
        OVERPRESSURE;
        LOW_FLOW;
        MOTOR_FAULT;
    }
    
    enumeration def ImpellerBladeCount {
        FIVE = 5;
    }
    
    // ===== Part Definitions =====
    
    part def MagneticBearingAssembly {
        attribute bearingType : BearingType = BearingType::MAGNETIC;
        attribute maxLoad : Real = 5000 [N];
        attribute stiffness : Real = 1e6 [N/m];
        attribute dampingCoefficient : Real = 200 [N*s/m];
        
        perform action stabilizeRotor {
            doc /* Actively stabilize the rotor position without physical contact. */
        }
    }
    
    part def ElectricMotor {
        attribute ratedPower : PowerValue = 7500 [W];
        attribute maxSpeed : RotationalSpeedValue = 314 [rad/s];
        attribute efficiency : FractionValue = 0.92;
        attribute supplyVoltage : VoltageValue = 480 [V];
        attribute supplyCurrent : CurrentValue;
        
        port electricalIn : ElectricalPort;
        port mechanicalOut : MechanicalPowerPort;
        
        perform action generateTorque {
            in speedCommand : RotationalSpeedValue;
            out shaftSpeed : RotationalSpeedValue;
            out shaftTorque : Real;
        }
    }
    
    port def MechanicalPowerPort {
        out shaftSpeed : RotationalSpeedValue;
        out shaftTorque : Real;
    }
    
    part def Impeller {
        attribute bladeCount : ImpellerBladeCount = ImpellerBladeCount::FIVE;
        attribute material : String = "StainlessSteel316L";
        attribute diameter : Real = 0.15 [m];
        attribute bladeAngle : Real = 30 [deg];
        
        perform action accelerateFluid {
            in fluidIn : CoolingFluid;
            in shaftSpeed : RotationalSpeedValue;
            out fluidOut : CoolingFluid;
        }
    }
    
    part def PumpCasing {
        attribute material : String = "StainlessSteel316L";
        attribute inletDiameter : Real = 0.08 [m];
        attribute outletDiameter : Real = 0.06 [m];
        attribute maxPressureRating : PressureValue = 2.5e6 [Pa];
        attribute volume : VolumeValue = 0.003 [m3];
    }
    
    part def CirculatingPump {
        attribute sealCount : Integer = 0;
        attribute designType : String = "Glandless";
        
        part motor : ElectricMotor;
        part impeller : Impeller;
        part casing : PumpCasing;
        part bearingAssembly : MagneticBearingAssembly;
        
        port fluidInlet : FluidPort;
        port fluidOutlet : FluidPort;
        port controlPort : ControlSignalPort;
        
        connection motorToImpeller connect motor.mechanicalOut to impeller;
        connection inletToCasing connect fluidInlet to casing;
        connection casingToImpeller connect casing to impeller;
        connection impellerToOutlet connect impeller to fluidOutlet;
        
        exhibit state pumpOperation {
            in speedCommand : RotationalSpeedValue;
            in fluidIn : CoolingFluid;
            out fluidOut : CoolingFluid;
            
            entry; then running;
            
            state running {
                do generateTorque(speedCommand);
                do accelerateFluid(fluidIn, speedCommand);
            }
            
            transition from running to running
                when speedCommand > 0;
        }
    }
    
    part def FluidReservoir {
        attribute capacity : VolumeValue = 0.2 [m3];
        attribute fluidVolume : VolumeValue = 0.15 [m3];
        attribute material : String = "StainlessSteel316L";
        attribute ambientPressure : PressureValue = 101325 [Pa];
        
        port fluidReturn : FluidPort;
        port fluidSupply : FluidPort;
        
        perform action storeFluid {
            in returnedFluid : CoolingFluid;
            out suppliedFluid : CoolingFluid;
        }
    }
    
    part def HeatExchanger {
        attribute thermalDuty : PowerValue = 75000 [W];
        attribute heatTransferArea : Real = 5.0 [m2];
        attribute overallHeatTransferCoeff : Real = 800 [W/(m2*K)];
        attribute pressureDrop : PressureValue = 50000 [Pa];
        
        port fluidInlet : FluidPort;
        port fluidOutlet : FluidPort;
        
        perform action transferHeat {
            in hotFluid : CoolingFluid;
            out cooledFluid : CoolingFluid;
        }
    }
    
    part def FlowSensor {
        attribute measurementRange : FlowRateValue = 0.5 [m3/s];
        attribute accuracy : FractionValue = 0.01;
        attribute responseTime : Real = 0.1 [s];
        
        port fluidPort : FluidPort;
        port signalOut : ControlSignalPort;
        
        perform action measureFlowRate {
            in fluid : CoolingFluid;
            out flowRate : FlowRateValue;
        }
    }
    
    part def PressureSensor {
        attribute measurementRange : PressureValue = 1e6 [Pa];
        attribute accuracy : FractionValue = 0.005;
        attribute responseTime : Real = 0.05 [s];
        
        port fluidPort : FluidPort;
        port signalOut : ControlSignalPort;
        
        perform action measurePressure {
            in fluid : CoolingFluid;
            out pressure : PressureValue;
        }
    }
    
    part def TemperatureSensor {
        attribute measurementRange : TemperatureValue = 100 [K];
        attribute accuracy : FractionValue = 0.01;
        attribute responseTime : Real = 0.2 [s];
        
        port fluidPort : FluidPort;
        port signalOut : ControlSignalPort;
        
        perform action measureTemperature {
            in fluid : CoolingFluid;
            out temperature : TemperatureValue;
        }
    }
    
    part def PumpController {
        attribute supportedModes : Set(OperatingMode) = {OperatingMode::NORMAL, OperatingMode::HIGH_DEMAND, OperatingMode::LOW_DEMAND};
        attribute tolerance : FlowRateValue = 0.02 [m3/s];
        attribute cavitationResponseTime : Real = 1 [s];
        attribute faultHandlingEnabled : Boolean = true;
        attribute currentMode : OperatingMode = OperatingMode::NORMAL;
        attribute currentFault : FaultType = FaultType::NONE;
        
        port commandIn : ControlSignalPort;
        port motorControlOut : ControlSignalPort;
        port sensorFeedbackIn : ControlSignalPort;
        
        exhibit state controllerStateMachine {
            in command : ControlCommand;
            in feedback : SensorFeedback;
            out motorSpeedCommand : RotationalSpeedValue;
            
            entry; then idle;
            
            state idle {
                doc /* System powered but not circulating. */
                assign motorSpeedCommand := 0 [rad/s];
            }
            
            state priming {
                doc /* Remove air from lines before normal circulation. */
                assign motorSpeedCommand := 50 [rad/s];
            }
            
            state normalCirculation {
                doc /* Standard operation meeting nominal flow demand. */
                assign motorSpeedCommand := 150 [rad/s];
            }
            
            state highDemandCirculation {
                doc /* Increased flow for high thermal load. */
                assign motorSpeedCommand := 300 [rad/s];
            }
            
            state lowDemandCirculation {
                doc /* Reduced flow for low thermal load. */
                assign motorSpeedCommand := 80 [rad/s];
            }
            
            state safeShutdown {
                doc /* Controlled ramp-down to protect equipment. */
                assign motorSpeedCommand := 0 [rad/s];
            }
            
            state fault {
                doc /* Fault condition detected; protective action active. */
                assign motorSpeedCommand := 0 [rad/s];
            }
            
            transition from idle to priming
                when command.targetFlowRate > 0 [m3/s];
            
            transition from priming to normalCirculation
                when feedback.measuredPressure > 200000 [Pa] and feedback.cavitationDetected == false;
            
            transition from normalCirculation to highDemandCirculation
                when command.operatingMode == OperatingMode::HIGH_DEMAND;
            
            transition from normalCirculation to lowDemandCirculation
                when command.operatingMode == OperatingMode::LOW_DEMAND;
            
            transition from highDemandCirculation to normalCirculation
                when command.operatingMode == OperatingMode::NORMAL;
            
            transition from lowDemandCirculation to normalCirculation
                when command.operatingMode == OperatingMode::NORMAL;
            
            transition from normalCirculation to safeShutdown
                when command.operatingMode == OperatingMode::SHUTDOWN;
            
            transition from highDemandCirculation to safeShutdown
                when command.operatingMode == OperatingMode::SHUTDOWN;
            
            transition from lowDemandCirculation to safeShutdown
                when command.operatingMode == OperatingMode::SHUTDOWN;
            
            transition from safeShutdown to idle
                when motorSpeedCommand == 0 [rad/s];
            
            transition from normalCirculation to fault
                when feedback.cavitationDetected == true;
            
            transition from highDemandCirculation to fault
                when feedback.cavitationDetected == true;
            
            transition from lowDemandCirculation to fault
                when feedback.cavitationDetected == true;
            
            transition from fault to safeShutdown
                when cavitationResponseTime <= 1 [s];
            
            transition from fault to idle
                when feedback.faultActive == false and command.operatingMode == OperatingMode::NORMAL;
        }
        
        perform action adjustMotorSpeed {
            in targetFlowRate : FlowRateValue;
            in measuredFlowRate : FlowRateValue;
            out speedCommand : RotationalSpeedValue;
            
            doc /* PID-style adjustment of motor speed based on flow rate error. */
        }
        
        perform action detectCavitation {
            in measuredPressure : PressureValue;
            in measuredFlowRate : FlowRateValue;
            out cavitationDetected : Boolean;
            
            doc /* Detect cavitation by monitoring pressure drops and flow anomalies. */
        }
    }
    
    // ===== Top-Level System =====
    
    part def CoolingCirculationSystem {
        attribute systemId : String = "CCS-001";
        attribute designLife : Real = 87600 [h];
        attribute maintenanceInterval : Real = 8760 [h];
        
        part pump : CirculatingPump;
        part reservoir : FluidReservoir;
        part heatExchanger : HeatExchanger;
        part controller : PumpController;
        part flowSensor : FlowSensor;
        part pressureSensor : PressureSensor;
        part temperatureSensor : TemperatureSensor;
        
        // Closed-loop fluid connections
        connection reservoirToPump connect reservoir.fluidSupply to pump.fluidInlet;
        connection pumpToHeatExchanger connect pump.fluidOutlet to heatExchanger.fluidInlet;
        connection heatExchangerToReservoir connect heatExchanger.fluidOutlet to reservoir.fluidReturn;
        
        // Sensor connections
        connection pumpToFlowSensor connect pump.fluidOutlet to flowSensor.fluidPort;
        connection pumpToPressureSensor connect pump.fluidOutlet to pressureSensor.fluidPort;
        connection heatExchangerToTempSensor connect heatExchanger.fluidOutlet to temperatureSensor.fluidPort;
        
        // Control and feedback connections
        connection controllerToMotor connect controller.motorControlOut to pump.controlPort;
        connection flowSensorToController connect flowSensor.signalOut to controller.sensorFeedbackIn;
        connection pressureSensorToController connect pressureSensor.signalOut to controller.sensorFeedbackIn;
        connection temperatureSensorToController connect temperatureSensor.signalOut to controller.sensorFeedbackIn;
        
        satisfy ClosedLoopOperationRequirement by system;
        satisfy LeakPreventionRequirement by pump;
        satisfy FlowControlRequirement by controller;
        satisfy FaultProtectionRequirement by system;
        satisfy MonitoringRequirement by system;
        
        exhibit state systemOperation {
            in externalCommand : ControlCommand;
            in ambientTemperature : TemperatureValue;
            out systemStatus : SensorFeedback;
            
            entry; then idle;
            
            state idle {
                doc /* System idle, awaiting start command. */
            }
            
            state priming {
                doc /* Priming pump to evacuate air from lines. */
            }
            
            state normalCirculation {
                doc /* Steady-state circulation at nominal flow rate. */
            }
            
            state highDemandCirculation {
                doc /* Elevated flow for peak thermal load. */
            }
            
            state lowDemandCirculation {
                doc /* Reduced flow for low thermal load. */
            }
            
            state safeShutdown {
                doc /* Graceful shutdown sequence. */
            }
            
            state fault {
                doc /* Fault handling state, e.g., cavitation detected. */
            }
            
            transition from idle to priming
                when externalCommand.targetFlowRate > 0 [m3/s];
            
            transition from priming to normalCirculation
                when systemStatus.measuredPressure > 200000 [Pa];
            
            transition from normalCirculation to highDemandCirculation
                when externalCommand.operatingMode == OperatingMode::HIGH_DEMAND;
            
            transition from normalCirculation to lowDemandCirculation
                when externalCommand.operatingMode == OperatingMode::LOW_DEMAND;
            
            transition from highDemandCirculation to normalCirculation
                when externalCommand.operatingMode == OperatingMode::NORMAL;
            
            transition from lowDemandCirculation to normalCirculation
                when externalCommand.operatingMode == OperatingMode::NORMAL;
            
            transition from normalCirculation to safeShutdown
                when externalCommand.operatingMode == OperatingMode::SHUTDOWN;
            
            transition from safeShutdown to idle
                when systemStatus.measuredFlowRate == 0 [m3/s];
            
            transition from normalCirculation to fault
                when systemStatus.cavitationDetected == true;
            
            transition from highDemandCirculation to fault
                when systemStatus.cavitationDetected == true;
            
            transition from lowDemandCirculation to fault
                when systemStatus.cavitationDetected == true;
            
            transition from fault to safeShutdown
                when systemStatus.faultActive == true;
            
            transition from fault to idle
                when systemStatus.faultActive == false;
        }
    }
}
