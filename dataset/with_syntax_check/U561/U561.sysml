package 'Sinusoidal Pumping Subsystem' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    package Definitions {
        item def Fluid {
            attribute density : Real;
            attribute viscosity : Real;
            attribute temperature : Real;
        }
        
        attribute def VolumeFlowRateValue :> Real;
        attribute def PressureValue :> Real;
        attribute def FrequencyValue :> Real;
        attribute def AmplitudeValue :> Real;
        attribute def VolumeValue :> Real;
        attribute def LengthValue :> Real;
        attribute def AngularVelocityValue :> Real;
        attribute def TorqueValue :> Real;
        attribute def PowerValue :> Real;
        
        port def FluidPort {
            attribute pressure : PressureValue;
            attribute flowRate : VolumeFlowRateValue;
            inout item fluid : Fluid;
        }
        
        port def MechanicalDrivePort {
            in attribute angularVelocity : AngularVelocityValue;
            in attribute torque : TorqueValue;
        }
        
        part def SinusoidalRotor {
            attribute wavelength : LengthValue;
            attribute amplitude : LengthValue;
            attribute numberOfLobes : Integer;
            attribute rotationAngle : Real;
        }
        
        part def Stator {
            attribute innerDiameter : LengthValue;
            attribute length : LengthValue;
        }
        
        part def SinusoidalPump {
            attribute nominalFlowRate : VolumeFlowRateValue;
            attribute operatingFrequency : FrequencyValue;
            attribute flowAmplitude : AmplitudeValue;
            attribute maxPressure : PressureValue;
            attribute displacementPerRevolution : VolumeValue;
            attribute efficiency : Real;
            attribute currentSpeed : AngularVelocityValue;
            attribute targetSpeed : AngularVelocityValue;
            
            port inletPort : FluidPort;
            port outletPort : FluidPort;
            port drivePort : MechanicalDrivePort;
            
            part rotor : SinusoidalRotor {
                attribute :>> numberOfLobes = 2;
                attribute :>> amplitude = 0.015;
            }
            
            part stator : Stator;
            
            part sealingSystem {
                attribute sealIntegrity : Real;
            }
            
            attribute instantaneousFlowRate : VolumeFlowRateValue;
        }
        
        part def ElectricMotor {
            attribute ratedPower : PowerValue;
            attribute ratedSpeed : AngularVelocityValue;
            attribute efficiency : Real;
            
            port driveOutput : ~MechanicalDrivePort;
        }
        
        part def FluidReservoir {
            attribute capacity : VolumeValue;
            attribute currentLevel : VolumeValue;
            
            port outletPort : FluidPort;
            
            item storedFluid : Fluid {
                attribute volume : VolumeValue;
            }
        }
        
        part def ProcessVessel {
            attribute capacity : VolumeValue;
            attribute operatingPressure : PressureValue;
            
            port inletPort : FluidPort;
            
            item receivedFluid : Fluid {
                attribute volume : VolumeValue;
            }
        }
        
        action def TransferFluidSinusoidally {
            in attribute inputPressure : PressureValue;
            in attribute frequency : FrequencyValue;
            in attribute amplitude : AmplitudeValue;
            in item fluidIn : Fluid;
            
            out attribute outputPressure : PressureValue;
            out attribute currentFlowRate : VolumeFlowRateValue;
            out item fluidOut : Fluid;
            
            action initializeFlow {
                in item fluid : Fluid;
            }
            
            action modulateFlow {
                in attribute freq : FrequencyValue;
                in attribute amp : AmplitudeValue;
                out attribute modFlowRate : VolumeFlowRateValue;
            }
            
            action deliverFluid {
                in item fluid : Fluid;
                in attribute flowRate : VolumeFlowRateValue;
                out item deliveredFluid : Fluid;
            }
            
            first start;
            then initializeFlow;
            then modulateFlow;
            then deliverFluid;
            then done;
        }
        
        state def PumpOperatingStates {
            in attribute targetSpeed : AngularVelocityValue;
            in attribute maxPressure : PressureValue;
            in attribute nominalFlowRate : VolumeFlowRateValue;
            in attribute amplitude : AmplitudeValue;
            in attribute frequency : FrequencyValue;
            
            attribute currentSpeed : AngularVelocityValue;
            attribute flowRate : VolumeFlowRateValue;
            attribute outputPressure : PressureValue;
            attribute time : Real;
            
            entry; then stopped;
            
            state stopped;
            
            transition stopped_to_starting
                first stopped
                accept StartCommand
                then starting;
            
            state starting;
            
            transition starting_to_running
                first starting
                then running;
            
            state running {
                entry; then normalOperation;
                
                state normalOperation;
                
                state highPressureMode;
                
                transition normal_to_highPressure
                    first normalOperation
                    then highPressureMode;
                
                transition highPressure_to_normal
                    first highPressureMode
                    then normalOperation;
            }
            
            transition running_to_stopping
                first running
                accept StopCommand
                then stopping;
            
            state stopping;
            
            transition stopping_to_stopped
                first stopping
                then stopped;
        }
        
        requirement def FlowPerformanceRequirement {
            subject pump : SinusoidalPump;
            
            require sinusoidalFlowPattern {
                doc /* The pump shall deliver fluid with a sinusoidal flow rate variation. */
            }
            
            require flowRateRange {
                doc /* The pump shall maintain average flow rate within ±5% of nominal. */
            }
        }
        
        requirement def PressureRequirement {
            subject pump : SinusoidalPump;
            
            require maxPressureLimit {
                doc /* The pump shall not exceed maximum rated discharge pressure. */
            }
        }
        
        requirement def EfficiencyRequirement {
            subject pump : SinusoidalPump;
            
            require minimumEfficiency {
                doc /* The pump shall operate at minimum 80% volumetric efficiency. */
            }
        }
    }
    
    package Usages {
        part pumpingSubsystem {
            part sourceReservoir : FluidReservoir {
                attribute :>> capacity = 500.0;
                attribute :>> currentLevel = 400.0;
                
                item :>> storedFluid : Fluid {
                    attribute :>> density = 1000.0;
                    attribute :>> viscosity = 0.001;
                    attribute :>> temperature = 298.15;
                    attribute :>> volume = 400.0;
                }
            }
            
            flow of transferFluid : Fluid
                from sourceReservoir.outletPort.fluid 
                to sinusoidalPump.inletPort.fluid;
            
            part driveMotor : ElectricMotor {
                attribute :>> ratedPower = 3000.0;
                attribute :>> ratedSpeed = 157.08;
                attribute :>> efficiency = 0.92;
            }
            
            connect driveMotor.driveOutput to sinusoidalPump.drivePort;
            
            part sinusoidalPump : SinusoidalPump {
                attribute :>> nominalFlowRate = 15.0;
                attribute :>> operatingFrequency = 1.5;
                attribute :>> flowAmplitude = 3.0;
                attribute :>> maxPressure = 600000.0;
                attribute :>> displacementPerRevolution = 0.006;
                attribute :>> efficiency = 0.85;
                attribute :>> currentSpeed = 0.0;
                attribute :>> targetSpeed = 157.08;
                
                part :>> rotor : SinusoidalRotor {
                    attribute :>> wavelength = 0.25;
                    attribute :>> amplitude = 0.015;
                    attribute :>> numberOfLobes = 2;
                    attribute :>> rotationAngle = 0.0;
                }
                
                part :>> stator : Stator {
                    attribute :>> innerDiameter = 0.08;
                    attribute :>> length = 0.5;
                }
                
                part :>> sealingSystem {
                    attribute :>> sealIntegrity = 0.98;
                }
                
                perform action pumpOperation : TransferFluidSinusoidally {
                    in inputPressure = inletPort.pressure;
                    in frequency = operatingFrequency;
                    in amplitude = flowAmplitude;
                    in fluidIn = inletPort.fluid;
                    
                    out outputPressure = outletPort.pressure;
                    out currentFlowRate = instantaneousFlowRate;
                    out fluidOut = outletPort.fluid;
                }
                
                exhibit state operatingStates : PumpOperatingStates {
                    in targetSpeed = sinusoidalPump.targetSpeed;
                    in maxPressure = sinusoidalPump.maxPressure;
                    in nominalFlowRate = sinusoidalPump.nominalFlowRate;
                    in amplitude = sinusoidalPump.flowAmplitude;
                    in frequency = sinusoidalPump.operatingFrequency;
                }
            }
            
            flow of deliveredFluid : Fluid
                from sinusoidalPump.outletPort.fluid 
                to processVessel.inletPort.fluid;
            
            part processVessel : ProcessVessel {
                attribute :>> capacity = 1000.0;
                attribute :>> operatingPressure = 500000.0;
                
                item :>> receivedFluid : Fluid {
                    attribute :>> volume = 100.0;
                }
            }
            
            satisfy flowPerformanceReq : FlowPerformanceRequirement {
                subject pump = sinusoidalPump;
            }
            
            satisfy pressureReq : PressureRequirement {
                subject pump = sinusoidalPump;
            }
            
            satisfy efficiencyReq : EfficiencyRequirement {
                subject pump = sinusoidalPump;
            }
            
            assert constraint VerifyFlowPattern {
                sinusoidalPump.instantaneousFlowRate >= 0.0
            }
            
            assert constraint VerifyPressureLimit {
                sinusoidalPump.outletPort.pressure <= sinusoidalPump.maxPressure
            }
        }
    }
}
