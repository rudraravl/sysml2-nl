package 'Radial Piston Pump Subsystem' {
    private import ScalarValues::*;
    private import ISQ::*;
    
    package Units {
        attribute def PressureValue :> Real;
        attribute def VolumeFlowRateValue :> Real;
        attribute def VolumeValue :> Real;
        attribute def AngularVelocityValue :> Real;
        attribute def TorqueValue :> Real;
        attribute def PowerValue :> Real;
        attribute def LengthValue :> Real;
        attribute def TemperatureValue :> Real;
        attribute def ViscosityValue :> Real;
    }
    
    package Definitions {
        private import Units::*;
        
        item def HydraulicFluid {
            attribute pressure : PressureValue;
            attribute temperature : TemperatureValue;
            attribute viscosity : ViscosityValue;
            attribute density : Real;
        }
        
        port def FluidInPort {
            in item fluidIn : HydraulicFluid;
            attribute inletPressure : PressureValue;
        }
        
        port def FluidOutPort {
            out item fluidOut : HydraulicFluid;
            attribute outletPressure : PressureValue;
            attribute flowRate : VolumeFlowRateValue;
        }
        
        port def MechanicalDrivePort {
            attribute torque : TorqueValue;
            attribute speed : AngularVelocityValue;
        }
        
        part def Piston {
            attribute diameter : LengthValue;
            attribute stroke : LengthValue;
            attribute position : LengthValue;
            attribute displacement : VolumeValue;
        }
        
        part def Cylinder {
            attribute bore : LengthValue;
            attribute volume : VolumeValue;
            port pistonInterface;
            port inletValve : FluidInPort;
            port outletValve : FluidOutPort;
        }
        
        part def CamRing {
            attribute eccentricity : LengthValue;
            attribute innerRadius : LengthValue;
            attribute outerRadius : LengthValue;
        }
        
        part def DriveShaft {
            attribute rotationSpeed : AngularVelocityValue;
            attribute angularPosition : Real;
            port driveConnection : MechanicalDrivePort;
        }
        
        part def CheckValve {
            attribute crackingPressure : PressureValue;
            attribute isOpen : Boolean;
            port inlet : FluidInPort;
            port outlet : FluidOutPort;
        }
        
        part def RadialPistonPump {
            attribute numberOfPistons : Integer;
            attribute totalDisplacement : VolumeValue;
            attribute maxPressure : PressureValue;
            attribute maxSpeed : AngularVelocityValue;
            attribute volumetricEfficiency : Real;
            attribute mechanicalEfficiency : Real;
            
            port suctionPort : FluidInPort;
            port dischargePort : FluidOutPort;
            port drivePort : MechanicalDrivePort;
            
            part driveShaft : DriveShaft;
            part camRing : CamRing {
                attribute :>> eccentricity = 0.012;
                attribute :>> innerRadius = 0.045;
                attribute :>> outerRadius = 0.065;
            }
            part pistons : Piston[7];
            part cylinders : Cylinder[7];
            part inletValves : CheckValve[7];
            part outletValves : CheckValve[7];
            
            perform action pumpingOperation : PumpingCycle;
            exhibit state operatingState : PumpOperatingStates;
        }
        
        part def FluidReservoir {
            attribute capacity : VolumeValue;
            attribute currentLevel : VolumeValue;
            attribute minLevel : VolumeValue;
            port outletPort : FluidOutPort;
            item storedFluid : HydraulicFluid {
                attribute :>> pressure = 101325.0;
                attribute :>> temperature = 293.15;
            }
        }
        
        part def AccumulatorVessel {
            attribute capacity : VolumeValue;
            attribute prechargeGasPressure : PressureValue;
            attribute currentPressure : PressureValue;
            attribute maxPressure : PressureValue;
            port inletPort : FluidInPort;
            item containedFluid : HydraulicFluid;
        }
        
        part def ElectricMotor {
            attribute ratedPower : PowerValue;
            attribute ratedSpeed : AngularVelocityValue;
            attribute ratedTorque : TorqueValue;
            attribute currentSpeed : AngularVelocityValue;
            port outputShaft : MechanicalDrivePort;
            
            perform action motorDrive : MotorOperation;
        }
        
        part def PressureTransducer {
            attribute measuredPressure : PressureValue;
            attribute accuracy : Real;
            attribute range : PressureValue;
        }
        
        part def FlowMeter {
            attribute measuredFlowRate : VolumeFlowRateValue;
            attribute accuracy : Real;
            attribute range : VolumeFlowRateValue;
        }
        
        part def TemperatureSensor {
            attribute measuredTemperature : TemperatureValue;
            attribute accuracy : Real;
        }
        
        part def ReliefValve {
            attribute setPointPressure : PressureValue;
            attribute isOpen : Boolean;
            port inlet : FluidInPort;
            port outlet : FluidOutPort;
        }
        
        action def PumpingCycle {
            in driveTorque : TorqueValue;
            in driveSpeed : AngularVelocityValue;
            in suctionFluid : HydraulicFluid;
            in suctionPressure : PressureValue;
            out dischargeFluid : HydraulicFluid;
            out dischargePressure : PressureValue;
            out dischargeFlowRate : VolumeFlowRateValue;
            
            first start;
            then action intakePhase {
                in pistonRetraction : LengthValue;
                out cylinderFilling : VolumeValue;
                out inletValveOpen : Boolean;
            }
            then action compressionPhase {
                in cylinderVolume : VolumeValue;
                out pressureRise : PressureValue;
            }
            then action dischargePhase {
                in compressionPressure : PressureValue;
                out fluidExpulsion : VolumeValue;
                out outletValveOpen : Boolean;
            }
            then merge continueCycle;
            then continueCycle;
        }
        
        action def MotorOperation {
            in electricalPower : PowerValue;
            out mechanicalTorque : TorqueValue;
            out shaftSpeed : AngularVelocityValue;
        }
        
        state def PumpOperatingStates {
            entry; then idle;
            
            state idle;
            
            transition idle_to_startup
                first idle
                accept StartSignal
                then startup;
            
            state startup;
            
            transition startup_to_priming
                first startup
                if speedReached
                then priming;
            
            state priming;
            
            transition priming_to_operating
                first priming
                if pressureEstablished
                then operating;
            
            state operating {
                state normalFlow;
                
                state highPressure;
                
                transition normal_to_high
                    first normalFlow
                    if dischargePressure > pressureThreshold
                    then highPressure;
                
                transition high_to_normal
                    first highPressure
                    if dischargePressure <= pressureThreshold
                    then normalFlow;
            }
            
            transition operating_to_shutdown
                first operating
                accept StopSignal
                then shutdown;
            
            state shutdown;
            
            transition shutdown_to_idle
                first shutdown
                if speedZero
                then idle;
            
            transition any_to_fault
                first operating
                if overpressure or overtemperature or cavitation
                then fault;
            
            state fault;
            
            transition fault_to_idle
                first fault
                accept ResetSignal
                then idle;
        }
        
        interface def FluidInterface {
            end port supplier : FluidOutPort;
            end port consumer : FluidInPort;
            connect supplier to consumer;
        }
        
        requirement def PumpPerformanceRequirement {
            subject pump : RadialPistonPump;
            
            doc /* The radial piston pump shall deliver specified flow rate and pressure. */
            
            require flowCapability {
                doc /* The pump shall deliver minimum flow rate of 60 L/min at rated speed. */
                attribute minFlowRate : VolumeFlowRateValue = 0.001;
                
                assert constraint {
                    pump.dischargePort.flowRate >= minFlowRate
                }
            }
            
            require pressureCapability {
                doc /* The pump shall achieve maximum discharge pressure of 35 MPa. */
                attribute maxDischargePressure : PressureValue = 35000000.0;
                
                assert constraint {
                    pump.dischargePort.outletPressure <= maxDischargePressure
                }
            }
            
            require efficiencyRequirement {
                doc /* The pump shall maintain volumetric efficiency above 92%. */
                attribute minEfficiency : Real = 0.92;
                
                assert constraint {
                    pump.volumetricEfficiency >= minEfficiency
                }
            }
        }
        
        requirement def SystemSafetyRequirement {
            subject subsystem : PumpingSubsystem;
            
            doc /* The pumping subsystem shall operate safely within design limits. */
            
            require overpressureProtection {
                doc /* The system shall prevent pressure exceeding maximum design pressure. */
                
                assert constraint {
                    subsystem.reliefValve.setPointPressure <= subsystem.accumulator.maxPressure
                }
            }
            
            require reservoirLevel {
                doc /* The reservoir level shall remain above minimum to prevent cavitation. */
                
                assert constraint {
                    subsystem.reservoir.currentLevel >= subsystem.reservoir.minLevel
                }
            }
            
            require temperatureLimit {
                doc /* The fluid temperature shall not exceed maximum operating temperature. */
                attribute maxTemperature : TemperatureValue = 353.15;
                
                assert constraint {
                    subsystem.tempSensor.measuredTemperature <= maxTemperature
                }
            }
        }
        
        requirement def ReliabilityRequirement {
            subject subsystem : PumpingSubsystem;
            
            doc /* The subsystem shall operate reliably with minimal maintenance. */
            
            require continuousOperation {
                doc /* The pump shall operate continuously for 5000 hours between maintenance. */
            }
            
            require faultDetection {
                doc /* The system shall detect and respond to fault conditions. */
            }
        }
        
        part def PumpingSubsystem {
            part reservoir : FluidReservoir;
            part motor : ElectricMotor;
            part radialPump : RadialPistonPump;
            part accumulator : AccumulatorVessel;
            part dischargePressureSensor : PressureTransducer;
            part flowMeter : FlowMeter;
            part tempSensor : TemperatureSensor;
            part reliefValve : ReliefValve;
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        part pumpingSubsystem : PumpingSubsystem {
            part :>> reservoir {
                attribute :>> capacity = 0.200;
                attribute :>> currentLevel = 0.150;
                attribute :>> minLevel = 0.050;
            }
            
            part :>> motor {
                attribute :>> ratedPower = 18500.0;
                attribute :>> ratedSpeed = 157.08;
                attribute :>> ratedTorque = 117.7;
                attribute :>> currentSpeed = 0.0;
            }
            
            part :>> radialPump {
                attribute :>> numberOfPistons = 7;
                attribute :>> totalDisplacement = 0.000125;
                attribute :>> maxPressure = 35000000.0;
                attribute :>> maxSpeed = 188.5;
                attribute :>> volumetricEfficiency = 0.95;
                attribute :>> mechanicalEfficiency = 0.93;
                
                part :>> pistons[1] {
                    attribute :>> diameter = 0.020;
                    attribute :>> stroke = 0.024;
                    attribute :>> displacement = 0.0000075;
                }
                
                part :>> pistons[2] {
                    attribute :>> diameter = 0.020;
                    attribute :>> stroke = 0.024;
                    attribute :>> displacement = 0.0000075;
                }
                
                part :>> pistons[3] {
                    attribute :>> diameter = 0.020;
                    attribute :>> stroke = 0.024;
                    attribute :>> displacement = 0.0000075;
                }
                
                part :>> pistons[4] {
                    attribute :>> diameter = 0.020;
                    attribute :>> stroke = 0.024;
                    attribute :>> displacement = 0.0000075;
                }
                
                part :>> pistons[5] {
                    attribute :>> diameter = 0.020;
                    attribute :>> stroke = 0.024;
                    attribute :>> displacement = 0.0000075;
                }
                
                part :>> pistons[6] {
                    attribute :>> diameter = 0.020;
                    attribute :>> stroke = 0.024;
                    attribute :>> displacement = 0.0000075;
                }
                
                part :>> pistons[7] {
                    attribute :>> diameter = 0.020;
                    attribute :>> stroke = 0.024;
                    attribute :>> displacement = 0.0000075;
                }
                
                part :>> driveShaft {
                    attribute :>> rotationSpeed = 157.08;
                    attribute :>> angularPosition = 0.0;
                }
                
                part :>> inletValves[1] {
                    attribute :>> crackingPressure = 5000.0;
                    attribute :>> isOpen = false;
                }
                
                part :>> outletValves[1] {
                    attribute :>> crackingPressure = 100000.0;
                    attribute :>> isOpen = false;
                }
            }
            
            part :>> accumulator {
                attribute :>> capacity = 0.010;
                attribute :>> prechargeGasPressure = 10000000.0;
                attribute :>> currentPressure = 25000000.0;
                attribute :>> maxPressure = 40000000.0;
            }
            
            part :>> dischargePressureSensor {
                attribute :>> accuracy = 0.005;
                attribute :>> range = 40000000.0;
            }
            
            part :>> flowMeter {
                attribute :>> accuracy = 0.01;
                attribute :>> range = 0.002;
            }
            
            part :>> tempSensor {
                attribute :>> accuracy = 0.5;
            }
            
            part :>> reliefValve {
                attribute :>> setPointPressure = 38000000.0;
                attribute :>> isOpen = false;
            }
            
            interface suctionInterface : FluidInterface
                connect supplier ::> reservoir.outletPort
                to consumer ::> radialPump.suctionPort;
            
            interface dischargeInterface : FluidInterface
                connect supplier ::> radialPump.dischargePort
                to consumer ::> accumulator.inletPort;
            
            flow of hydraulicFluid : HydraulicFluid
                from reservoir.outletPort.fluidOut
                to radialPump.suctionPort.fluidIn;
            
            flow of hydraulicFluid : HydraulicFluid
                from radialPump.dischargePort.fluidOut
                to accumulator.inletPort.fluidIn;
            
            bind motor.outputShaft.torque = radialPump.drivePort.torque;
            bind motor.outputShaft.speed = radialPump.drivePort.speed;
            
            bind dischargePressureSensor.measuredPressure = radialPump.dischargePort.outletPressure;
            bind flowMeter.measuredFlowRate = radialPump.dischargePort.flowRate;
            
            connect reliefValve.inlet to radialPump.dischargePort;
            connect reliefValve.outlet to reservoir.outletPort;
            
            satisfy performanceReq : PumpPerformanceRequirement {
                subject pump = radialPump;
            }
            
            satisfy safetyReq : SystemSafetyRequirement {
                subject subsystem = pumpingSubsystem;
            }
            
            satisfy reliabilityReq : ReliabilityRequirement {
                subject subsystem = pumpingSubsystem;
            }
        }
    }
}
