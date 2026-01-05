package PumpjackSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    package Definitions {
        attribute def StrokeRate :> FrequencyValue;
        attribute def StrokeLength :> LengthValue;
        attribute def FluidLevel :> LengthValue;
        attribute def ProductionRate :> VolumeFlowValue;
        attribute def WellDepth :> LengthValue;
        attribute def CrankAngle :> Real;
        
        attribute def StartCommand;
        attribute def StopCommand;
        attribute def EmergencyStop;
        
        item def CrudeOil {
            attribute density : DensityValue;
            attribute viscosity : DynamicViscosityValue;
        }
        
        item def ProducedFluid {
            attribute oilContent : CrudeOil;
            attribute waterCut : Real;
            attribute gasContent : VolumeValue;
        }
        
        port def ElectricalPowerPort {
            in attribute voltage : ElectricPotentialValue;
            in attribute current : ElectricCurrentValue;
            out attribute power : PowerValue;
        }
        
        port def MechanicalDrivePort {
            out attribute torque : TorqueValue;
            out attribute rotationalSpeed : AngularVelocityValue;
        }
        
        port def FluidOutputPort {
            out item fluid : ProducedFluid;
            out attribute flowRate : ProductionRate;
            out attribute pressure : PressureValue;
        }
        
        part def ElectricMotor {
            attribute ratedPower : PowerValue;
            attribute efficiency : Real;
            port powerIn : ElectricalPowerPort;
            port driveOut : MechanicalDrivePort;
        }
        
        part def SpeedReducer {
            attribute reductionRatio : Real;
            port driveIn : ~MechanicalDrivePort;
            port driveOut : MechanicalDrivePort;
        }
        
        part def CrankAssembly {
            attribute crankRadius : LengthValue;
            attribute counterweightMass : MassValue;
            port driveIn : ~MechanicalDrivePort;
            out attribute crankPosition : CrankAngle;
        }
        
        part def WalkingBeam {
            attribute beamLength : LengthValue;
            attribute pivotOffset : LengthValue;
            in attribute crankMotion : CrankAngle;
            out attribute verticalStroke : StrokeLength;
        }
        
        part def PolishedRodString {
            attribute rodDiameter : LengthValue;
            attribute totalLength : WellDepth;
            in attribute surfaceStroke : StrokeLength;
            out attribute downholeStroke : StrokeLength;
            out attribute rodLoad : ForceValue;
        }
        
        part def SubsurfacePump {
            attribute plungerDiameter : LengthValue;
            attribute pumpSettingDepth : WellDepth;
            in attribute pumpStroke : StrokeLength;
            port fluidOut : FluidOutputPort;
        }
        
        part def ProductionTubing {
            attribute tubingDiameter : LengthValue;
            attribute tubingDepth : WellDepth;
            port fluidIn : ~FluidOutputPort;
            port fluidOut : FluidOutputPort;
        }
        
        part def Wellhead {
            attribute operatingPressure : PressureValue;
            port fluidIn : ~FluidOutputPort;
            port productionOut : FluidOutputPort;
        }
        
        part def FlowlineSystem {
            attribute pipelineDiameter : LengthValue;
            attribute destinationDistance : LengthValue;
            port fluidIn : ~FluidOutputPort;
        }
        
        part def ControlSystem {
            attribute targetStrokeRate : StrokeRate;
            attribute maxStrokeRate : StrokeRate;
            attribute minStrokeRate : StrokeRate;
            out attribute commandedSpeed : AngularVelocityValue;
        }
        
        part def Pumpjack;
        
        action def ConvertElectricalPower {
            in electricalPower : PowerValue;
            in efficiency : Real;
            out mechanicalTorque : TorqueValue;
            out rotationalSpeed : AngularVelocityValue;
        }
        
        action def ReduceSpeed {
            in inputTorque : TorqueValue;
            in inputSpeed : AngularVelocityValue;
            in reductionRatio : Real;
            out outputTorque : TorqueValue;
            out outputSpeed : AngularVelocityValue;
        }
        
        action def ConvertRotaryToReciprocating {
            in crankTorque : TorqueValue;
            in crankSpeed : AngularVelocityValue;
            in crankRadius : LengthValue;
            out verticalStroke : StrokeLength;
            out strokeRate : StrokeRate;
        }
        
        action def TransmitStroke {
            in surfaceStroke : StrokeLength;
            in rodLength : WellDepth;
            out downholeStroke : StrokeLength;
            out rodLoad : ForceValue;
        }
        
        action def LiftFluid {
            in pumpStroke : StrokeLength;
            in strokeRate : StrokeRate;
            in fluidDensity : DensityValue;
            in wellDepth : WellDepth;
            out liftedFluid : ProducedFluid;
            out productionRate : ProductionRate;
        }
        
        action def TransportFluid {
            in producedFluid : ProducedFluid;
            in flowRate : ProductionRate;
            out deliveredFluid : ProducedFluid;
        }
        
        action def ExtractOil;
        
        state def PumpjackOperationalStates {
            entry; then idle;
            
            state idle;
            
            accept start : StartCommand;
            then pumping;
            
            state pumping {
                entry; then upstroke;
                
                state upstroke;
                then downstroke;
                
                state downstroke;
                then upstroke;
            }
            
            accept stop : StopCommand;
            then idle;
            
            accept emergency : EmergencyStop;
            then shutdown;
            
            state shutdown;
        }
        
        requirement def SystemFunction;
        requirement def PerformanceRequirement;
        requirement def SafetyRequirement;
        requirement def ReliabilityRequirement;
    }
    
    package Usages {
        part pumpjackSystem : Definitions::Pumpjack {
            doc /* 
                A pumpjack is an artificial lift system that extracts crude oil from subsurface 
                reservoirs by converting rotary motion from a prime mover into reciprocating 
                vertical motion that drives a downhole pump to lift reservoir fluids to the surface.
            */
            
            attribute systemStrokeRate : Definitions::StrokeRate = 12.0 [SI::Hz];
            attribute systemStrokeLength : Definitions::StrokeLength = 2.4 [SI::m];
            attribute wellDepth : Definitions::WellDepth = 1200.0 [SI::m];
            attribute dailyProduction : Definitions::ProductionRate;
            
            part motor : Definitions::ElectricMotor {
                attribute ratedPower = 22000.0 [SI::W];
                attribute efficiency = 0.93;
            }
            
            part reducer : Definitions::SpeedReducer {
                attribute reductionRatio = 35.0;
            }
            
            part crank : Definitions::CrankAssembly {
                attribute crankRadius = 0.75 [SI::m];
                attribute counterweightMass = 1800.0 [SI::kg];
            }
            
            part beam : Definitions::WalkingBeam {
                attribute beamLength = 5.5 [SI::m];
                attribute pivotOffset = 2.2 [SI::m];
            }
            
            part rodString : Definitions::PolishedRodString {
                attribute rodDiameter = 0.022 [SI::m];
                attribute totalLength = pumpjackSystem.wellDepth;
            }
            
            part downholePump : Definitions::SubsurfacePump {
                attribute plungerDiameter = 0.044 [SI::m];
                attribute pumpSettingDepth = 1150.0 [SI::m];
            }
            
            part tubing : Definitions::ProductionTubing {
                attribute tubingDiameter = 0.062 [SI::m];
                attribute tubingDepth = 1180.0 [SI::m];
            }
            
            part wellhead : Definitions::Wellhead {
                attribute operatingPressure = 2500000.0 [SI::Pa];
            }
            
            part flowline : Definitions::FlowlineSystem {
                attribute pipelineDiameter = 0.076 [SI::m];
                attribute destinationDistance = 500.0 [SI::m];
            }
            
            part controller : Definitions::ControlSystem {
                attribute targetStrokeRate = pumpjackSystem.systemStrokeRate;
                attribute maxStrokeRate = 20.0 [SI::Hz];
                attribute minStrokeRate = 4.0 [SI::Hz];
            }
            
            connect motor.driveOut to reducer.driveIn;
            connect reducer.driveOut to crank.driveIn;
            connect crank.crankPosition to beam.crankMotion;
            connect beam.verticalStroke to rodString.surfaceStroke;
            connect rodString.downholeStroke to downholePump.pumpStroke;
            connect downholePump.fluidOut to tubing.fluidIn;
            connect tubing.fluidOut to wellhead.fluidIn;
            connect wellhead.productionOut to flowline.fluidIn;
            
            exhibit operatingStates : pumpjackStates;
            perform extraction : extractionProcess;
        }
        
        state pumpjackStates : Definitions::PumpjackOperationalStates;
        
        action extractionProcess : Definitions::ExtractOil {
            doc /* 
                The primary extraction process converts electrical energy into mechanical 
                reciprocating motion to operate a subsurface pump that lifts reservoir fluids.
            */
            
            loop {
                accept startCmd : Definitions::StartCommand;
                then action {
                    action convertPower : Definitions::ConvertElectricalPower {
                        in electricalPower = pumpjackSystem.motor.ratedPower;
                        in efficiency = pumpjackSystem.motor.efficiency;
                        out mechanicalTorque;
                        out rotationalSpeed;
                    }
                    flow convertPower.mechanicalTorque to reduceSpeed.inputTorque;
                    flow convertPower.rotationalSpeed to reduceSpeed.inputSpeed;
                    
                    action reduceSpeed : Definitions::ReduceSpeed {
                        in reductionRatio = pumpjackSystem.reducer.reductionRatio;
                        out outputTorque;
                        out outputSpeed;
                    }
                    flow reduceSpeed.outputTorque to convertMotion.crankTorque;
                    flow reduceSpeed.outputSpeed to convertMotion.crankSpeed;
                    
                    action convertMotion : Definitions::ConvertRotaryToReciprocating {
                        in crankRadius = pumpjackSystem.crank.crankRadius;
                        out verticalStroke;
                        out strokeRate;
                    }
                    flow convertMotion.verticalStroke to transmitStroke.surfaceStroke;
                    
                    action transmitStroke : Definitions::TransmitStroke {
                        in rodLength = pumpjackSystem.rodString.totalLength;
                        out downholeStroke;
                        out rodLoad;
                    }
                    flow transmitStroke.downholeStroke to liftFluid.pumpStroke;
                    flow convertMotion.strokeRate to liftFluid.strokeRate;
                    
                    action liftFluid : Definitions::LiftFluid {
                        in fluidDensity;
                        in wellDepth = pumpjackSystem.wellDepth;
                        out liftedFluid;
                        out productionRate;
                    }
                    flow liftFluid.liftedFluid to transportFluid.producedFluid;
                    flow liftFluid.productionRate to transportFluid.flowRate;
                    
                    action transportFluid : Definitions::TransportFluid {
                        out deliveredFluid;
                    }
                }
                then accept stopCmd : Definitions::StopCommand;
            }
        }
        
        requirement primaryFunction : Definitions::SystemFunction {
            doc /* 
                The pumpjack system shall extract crude oil and associated fluids from subsurface 
                reservoirs by converting rotary motion into reciprocating motion to drive a 
                positive displacement pump that lifts fluids to the surface for collection and transport.
            */
            subject pumpjackSystem;
        }
        
        requirement productionPerformance : Definitions::PerformanceRequirement {
            doc /* 
                The system shall maintain a minimum daily production rate while operating 
                within specified stroke rate and stroke length parameters.
            */
            subject pumpjackSystem;
            
            require constraint {
                pumpjackSystem.dailyProduction >= 8.0 [SI::m^3/SI::day]
            }
            
            require constraint {
                pumpjackSystem.systemStrokeRate >= 4.0 [SI::Hz] and
                pumpjackSystem.systemStrokeRate <= 20.0 [SI::Hz]
            }
        }
        
        requirement mechanicalReliability : Definitions::ReliabilityRequirement {
            doc /* 
                The system shall operate continuously with mechanical components designed 
                for extended service life under cyclic loading conditions.
            */
            subject pumpjackSystem;
            
            require constraint {
                pumpjackSystem.rodString.rodLoad <= 80000.0 [SI::N]
            }
            
            require constraint {
                pumpjackSystem.motor.efficiency >= 0.90
            }
        }
        
        requirement operationalSafety : Definitions::SafetyRequirement {
            doc /* 
                The system shall operate within safe pressure limits and include emergency 
                shutdown capability to prevent equipment damage and ensure personnel safety.
            */
            subject pumpjackSystem;
            
            require constraint {
                pumpjackSystem.wellhead.operatingPressure <= 10000000.0 [SI::Pa]
            }
        }
        
        requirement systemRequirements {
            subject pumpjackSystem;
            
            require primaryFunction;
            require productionPerformance;
            require mechanicalReliability;
            require operationalSafety;
        }
    }
}
