package 'Froth Pumping Subsystem Model' {
    private import ScalarValues::*;
    private import ISQ::*;
    
    package Definitions {
        attribute def Pressure :> Real;
        attribute def FlowRate :> Real;
        attribute def RotationalSpeed :> Real;
        attribute def Power :> Real;
        attribute def Viscosity :> Real;
        attribute def Density :> Real;
        attribute def Temperature :> Real;
        attribute def GasFraction :> Real;
        attribute def SolidsFraction :> Real;
        
        item def FrothFluid {
            attribute density : Density;
            attribute viscosity : Viscosity;
            attribute temperature : Temperature;
            attribute gasFraction : GasFraction;
            attribute solidsFraction : SolidsFraction;
        }
        
        port def FluidInPort {
            attribute inletPressure : Pressure;
            attribute inletTemperature : Temperature;
            in item fluidIn : FrothFluid;
        }
        
        port def FluidOutPort {
            attribute outletPressure : Pressure;
            attribute outletTemperature : Temperature;
            out item fluidOut : FrothFluid;
        }
        
        port def MotorDrivePort {
            attribute torque : Real;
            attribute speed : RotationalSpeed;
            attribute powerTransfer : Power;
        }
        
        port def ControlSignalPort {
            in attribute commandSpeed : RotationalSpeed;
            in attribute startCommand : Boolean;
            in attribute stopCommand : Boolean;
            out attribute actualSpeed : RotationalSpeed;
            out attribute operatingStatus : String;
        }
        
        port def SensorPort {
            out attribute measuredPressure : Pressure;
            out attribute measuredFlowRate : FlowRate;
            out attribute measuredTemperature : Temperature;
        }
        
        interface def FluidTransferInterface {
            end port source : FluidOutPort;
            end port sink : FluidInPort;
        }
        
        interface def MechanicalDriveInterface {
            end port driver : MotorDrivePort;
            end port driven : ~MotorDrivePort;
        }
        
        action def PumpFrothFluid {
            in frothIn : FrothFluid;
            in driveSpeed : RotationalSpeed;
            in drivePower : Power;
            out frothOut : FrothFluid;
            out generatedPressure : Pressure;
            out achievedFlowRate : FlowRate;
        }
        
        action def MonitorPumpConditions {
            in inletPressure : Pressure;
            in outletPressure : Pressure;
            in flowRate : FlowRate;
            out cavitationDetected : Boolean;
            out overloadDetected : Boolean;
        }
        
        state def FrothPumpOperationStates {
            entry; then stopped;
            
            state stopped;
            accept StartCommand then priming;
            
            state priming;
            accept at inletPressure > minimumSuctionPressure then accelerating;
            accept StopCommand then stopping;
            
            state accelerating;
            accept at pumpSpeed >= targetSpeed then running;
            accept StopCommand then stopping;
            
            state running {
                state normalOperation;
                accept at flowRate < minimumFlowRate then lowFlowCondition;
                accept at outletPressure > maximumPressure then highPressureCondition;
                accept at cavitationDetected then cavitating;
                
                state lowFlowCondition;
                accept at flowRate >= minimumFlowRate then normalOperation;
                
                state highPressureCondition;
                accept at outletPressure <= maximumPressure then normalOperation;
                
                state cavitating;
                accept at not cavitationDetected then normalOperation;
            }
            accept StopCommand then stopping;
            accept EmergencyStop then emergency;
            
            state stopping;
            accept at pumpSpeed <= 0.0 then stopped;
            
            state emergency;
            accept ResetCommand then stopped;
        }
        
        part def FrothPump {
            attribute ratedFlowRate : FlowRate;
            attribute ratedPressure : Pressure;
            attribute ratedSpeed : RotationalSpeed;
            attribute efficiency : Real;
            attribute maximumGasFraction : GasFraction;
            attribute maximumSolidsFraction : SolidsFraction;
            attribute minimumSuctionPressure : Pressure;
            
            port inletPort : FluidInPort;
            port outletPort : FluidOutPort;
            port drivePort : ~MotorDrivePort;
            port controlPort : ControlSignalPort;
            port sensorPort : SensorPort;
            
            part impeller {
                attribute diameter : Real;
                attribute bladeCount : Integer;
                attribute bladeAngle : Real;
            }
            
            part casing {
                attribute material : String;
                attribute wearResistance : Real;
            }
            
            part shaft {
                attribute diameter : Real;
                attribute material : String;
            }
            
            part mechanicalSeal {
                attribute sealType : String;
                attribute maxPressure : Pressure;
            }
            
            perform action pumpOperation : PumpFrothFluid {
                in frothIn = inletPort.fluidIn;
                in driveSpeed = drivePort.speed;
                in drivePower = drivePort.powerTransfer;
                out frothOut = outletPort.fluidOut;
                out generatedPressure = sensorPort.measuredPressure;
                out achievedFlowRate = sensorPort.measuredFlowRate;
            }
            
            perform action monitoring : MonitorPumpConditions {
                in inletPressure = inletPort.inletPressure;
                in outletPressure = outletPort.outletPressure;
                in flowRate = sensorPort.measuredFlowRate;
                out cavitationDetected;
                out overloadDetected;
            }
            
            exhibit state operationControl : FrothPumpOperationStates {
                attribute targetSpeed = ratedSpeed;
                attribute minimumSpeed = ratedSpeed * 0.2;
                attribute minimumFlowRate = ratedFlowRate * 0.3;
                attribute maximumPressure = ratedPressure * 1.1;
                attribute minimumSuctionPressure = 50.0;
                attribute accelerationRate = 10.0;
                attribute decelerationRate = 20.0;
                attribute pumpSpeed : RotationalSpeed;
                attribute flowOutput : FlowRate;
                attribute inletPressure : Pressure;
                attribute outletPressure : Pressure;
                attribute flowRate : FlowRate;
                attribute cavitationDetected : Boolean;
                attribute inletValveOpen : Boolean;
                attribute emergencyValveClosed : Boolean;
            }
        }
        
        part def ElectricMotor {
            attribute ratedPower : Power;
            attribute ratedSpeed : RotationalSpeed;
            attribute voltage : Real;
            attribute current : Real;
            attribute powerFactor : Real;
            
            port driveShaft : MotorDrivePort;
            port controlInput : ~ControlSignalPort;
            
            perform action provideDrive {
                in commandSpeed = controlInput.commandSpeed;
                out torque = driveShaft.torque;
                out speed = driveShaft.speed;
                out powerTransfer = driveShaft.powerTransfer;
            }
        }
        
        part def SupplyTank {
            attribute capacity : Real;
            attribute currentLevel : Real;
            
            port outlet : FluidOutPort;
            
            item storedFroth : FrothFluid {
                attribute volume : Real;
            }
        }
        
        part def ReceivingTank {
            attribute capacity : Real;
            attribute currentLevel : Real;
            
            port inlet : FluidInPort;
            
            item receivedFroth : FrothFluid {
                attribute volume : Real;
            }
        }
        
        part def PipingSection {
            attribute length : Real;
            attribute diameter : Real;
            attribute material : String;
            attribute roughness : Real;
            
            port inlet : FluidInPort;
            port outlet : FluidOutPort;
        }
        
        part def PressureGauge {
            attribute reading : Pressure;
            attribute accuracy : Real;
            
            port measurementPoint : ~FluidOutPort;
        }
        
        part def FlowMeter {
            attribute reading : FlowRate;
            attribute accuracy : Real;
            
            port measurementPoint : ~FluidOutPort;
        }
        
        part def ControlValve {
            attribute position : Real;
            attribute flowCoefficient : Real;
            
            port inlet : FluidInPort;
            port outlet : FluidOutPort;
            
            perform action regulateFlow {
                in desiredFlow : FlowRate;
                in currentFlow : FlowRate;
                out valvePosition : Real;
            }
        }
        
        requirement def FlowRateRequirement {
            doc /* The pumping subsystem shall deliver the specified minimum flow rate. */
            
            subject pump : FrothPump;
            attribute minimumFlowRate : FlowRate;
            
            require constraint {
                pump.sensorPort.measuredFlowRate >= minimumFlowRate
            }
        }
        
        requirement def PressureRequirement {
            doc /* The pumping subsystem shall generate the specified discharge pressure. */
            
            subject pump : FrothPump;
            attribute requiredPressure : Pressure;
            
            require constraint {
                pump.outletPort.outletPressure >= requiredPressure
            }
        }
        
        requirement def FrothHandlingRequirement {
            doc /* The pump shall handle froth with specified gas and solids content. */
            
            subject pump : FrothPump;
            
            require constraint {
                pump.inletPort.fluidIn.gasFraction <= pump.maximumGasFraction and
                pump.inletPort.fluidIn.solidsFraction <= pump.maximumSolidsFraction
            }
        }
        
        requirement def EfficiencyRequirement {
            doc /* The pump shall operate at minimum specified efficiency. */
            
            subject pump : FrothPump;
            attribute minimumEfficiency : Real;
            
            require constraint {
                pump.efficiency >= minimumEfficiency
            }
        }
    }
    
    package Usages {
        import Definitions::*;
        
        part frothPumpingSubsystem {
            
            part supplyTank : SupplyTank {
                attribute :>> capacity = 10000.0;
                attribute :>> currentLevel = 7500.0;
                
                item :>> storedFroth : FrothFluid {
                    attribute :>> density = 1150.0;
                    attribute :>> viscosity = 45.0;
                    attribute :>> temperature = 298.0;
                    attribute :>> gasFraction = 0.20;
                    attribute :>> solidsFraction = 0.35;
                    attribute :>> volume = 7500.0;
                }
            }
            
            part suctionPiping : PipingSection {
                attribute :>> length = 8.0;
                attribute :>> diameter = 0.20;
                attribute :>> material = "Rubber-lined carbon steel";
                attribute :>> roughness = 0.0015;
            }
            
            flow of froth : FrothFluid 
                from supplyTank.outlet.fluidOut to suctionPiping.inlet.fluidIn;
            
            part suctionPressureGauge : PressureGauge {
                attribute :>> reading = 95.0;
                attribute :>> accuracy = 0.5;
            }
            
            bind suctionPressureGauge.measurementPoint = suctionPiping.outlet;
            
            part mainFrothPump : FrothPump {
                attribute :>> ratedFlowRate = 200.0;
                attribute :>> ratedPressure = 800.0;
                attribute :>> ratedSpeed = 1200.0;
                attribute :>> efficiency = 0.72;
                attribute :>> maximumGasFraction = 0.30;
                attribute :>> maximumSolidsFraction = 0.45;
                attribute :>> minimumSuctionPressure = 50.0;
                
                part :>> impeller {
                    attribute :>> diameter = 0.45;
                    attribute :>> bladeCount = 3;
                    attribute :>> bladeAngle = 25.0;
                }
                
                part :>> casing {
                    attribute :>> material = "High-chrome white iron";
                    attribute :>> wearResistance = 0.92;
                }
                
                part :>> shaft {
                    attribute :>> diameter = 0.10;
                    attribute :>> material = "Stainless steel 316L";
                }
                
                part :>> mechanicalSeal {
                    attribute :>> sealType = "Double mechanical seal with barrier fluid";
                    attribute :>> maxPressure = 1200.0;
                }
            }
            
            flow of froth : FrothFluid 
                from suctionPiping.outlet.fluidOut to mainFrothPump.inletPort.fluidIn;
            
            part pumpDriveMotor : ElectricMotor {
                attribute :>> ratedPower = 75.0;
                attribute :>> ratedSpeed = 1200.0;
                attribute :>> voltage = 480.0;
                attribute :>> current = 110.0;
                attribute :>> powerFactor = 0.88;
            }
            
            interface motorToPump : MechanicalDriveInterface 
                connect driver ::> pumpDriveMotor.driveShaft 
                to driven ::> mainFrothPump.drivePort;
            
            part dischargePiping : PipingSection {
                attribute :>> length = 25.0;
                attribute :>> diameter = 0.15;
                attribute :>> material = "Rubber-lined carbon steel";
                attribute :>> roughness = 0.0015;
            }
            
            flow of froth : FrothFluid 
                from mainFrothPump.outletPort.fluidOut to dischargePiping.inlet.fluidIn;
            
            part dischargePressureGauge : PressureGauge {
                attribute :>> reading = 850.0;
                attribute :>> accuracy = 1.0;
            }
            
            bind dischargePressureGauge.measurementPoint = dischargePiping.inlet;
            
            part dischargeFlowMeter : FlowMeter {
                attribute :>> reading = 198.5;
                attribute :>> accuracy = 2.0;
            }
            
            bind dischargeFlowMeter.measurementPoint = dischargePiping.outlet;
            
            part dischargeControlValve : ControlValve {
                attribute :>> position = 0.80;
                attribute :>> flowCoefficient = 250.0;
                
                perform :>> regulateFlow {
                    in :>> desiredFlow = 200.0;
                    in :>> currentFlow = dischargeFlowMeter.reading;
                    out :>> valvePosition = position;
                }
            }
            
            flow of froth : FrothFluid 
                from dischargePiping.outlet.fluidOut to dischargeControlValve.inlet.fluidIn;
            
            part receivingTank : ReceivingTank {
                attribute :>> capacity = 12000.0;
                attribute :>> currentLevel = 4200.0;
                
                item :>> receivedFroth : FrothFluid {
                    attribute :>> volume = 4200.0;
                }
            }
            
            flow of deliveredFroth : FrothFluid 
                from dischargeControlValve.outlet.fluidOut to receivingTank.inlet.fluidIn;
            
            bind receivingTank.receivedFroth = deliveredFroth;
            
            satisfy flowReq : FlowRateRequirement {
                subject pump = mainFrothPump;
                attribute :>> minimumFlowRate = 180.0;
            }
            
            satisfy pressureReq : PressureRequirement {
                subject pump = mainFrothPump;
                attribute :>> requiredPressure = 750.0;
            }
            
            satisfy frothHandlingReq : FrothHandlingRequirement {
                subject pump = mainFrothPump;
            }
            
            satisfy efficiencyReq : EfficiencyRequirement {
                subject pump = mainFrothPump;
                attribute :>> minimumEfficiency = 0.68;
            }
        }
    }
}
