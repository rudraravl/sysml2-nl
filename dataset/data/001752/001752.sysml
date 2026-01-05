package BicyclePumpSubsystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    package Definitions {
        item def Air {
            attribute temperature : TemperatureValue;
            attribute pressure : PressureValue;
            attribute volume : VolumeValue;
        }
        
        port def AirPort {
            out item airOut : Air;
        }
        
        part def AtmosphericSource {
            port airSupply : AirPort;
        }
        
        part def PistonChamber {
            attribute chamberVolume : VolumeValue;
            attribute currentPressure : PressureValue;
            port airInPort : ~AirPort;
            port airOutPort : AirPort;
        }
        
        part def Piston {
            attribute position : LengthValue;
            attribute maxStroke : LengthValue;
            attribute diameter : LengthValue;
        }
        
        part def CheckValve {
            attribute isOpen : Boolean;
            attribute crackingPressure : PressureValue;
            port inPort : ~AirPort;
            port outPort : AirPort;
        }
        
        part def PumpHandle {
            attribute handlePosition : LengthValue;
            attribute forceApplied : ForceValue;
        }
        
        part def PumpBody {
            attribute bodyLength : LengthValue;
            attribute internalDiameter : LengthValue;
        }
        
        part def Hose {
            attribute hoseLength : LengthValue;
            attribute hoseDiameter : LengthValue;
            port inPort : ~AirPort;
            port outPort : AirPort;
        }
        
        part def InflatableTarget {
            attribute targetPressure : PressureValue;
            attribute currentVolume : VolumeValue;
            port airInPort : ~AirPort;
            item storedAir : Air {
                attribute :>> volume;
                attribute :>> pressure;
            }
        }
        
        part def BicyclePump {
            port atmospherePort : ~AirPort;
            port outputPort : AirPort;
            
            part pumpBody : PumpBody {
                attribute :>> bodyLength = 300.0[mm];
                attribute :>> internalDiameter = 25.0[mm];
            }
            
            part piston : Piston {
                attribute :>> maxStroke = 250.0[mm];
                attribute :>> diameter = 24.5[mm];
                attribute :>> position = 0.0[mm];
            }
            
            part handle : PumpHandle {
                attribute :>> handlePosition = 0.0[mm];
            }
            
            part chamber : PistonChamber {
                attribute :>> chamberVolume = 0.00012[m^3];
                attribute :>> currentPressure = 101325.0[Pa];
            }
            
            part intakeValve : CheckValve {
                attribute :>> isOpen = false;
                attribute :>> crackingPressure = 100.0[Pa];
            }
            
            part outletValve : CheckValve {
                attribute :>> isOpen = false;
                attribute :>> crackingPressure = 200.0[Pa];
            }
            
            part hose : Hose {
                attribute :>> hoseLength = 500.0[mm];
                attribute :>> hoseDiameter = 6.0[mm];
            }
        }
        
        action def IntakeAir {
            in atmosphericAir : Air;
            out chamberAir : Air;
        }
        
        action def CompressAir {
            in pistonPosition : LengthValue;
            in chamberVolume : VolumeValue;
            out compressedAir : Air;
            out outletPressure : PressureValue;
        }
        
        action def TransferAir {
            in sourceAir : Air;
            out deliveredAir : Air;
        }
        
        action def PumpingCycle {
            first start;
            then merge continuePumping;
            
            then action pullHandle {
                out handlePos : LengthValue;
            }
            
            then action intakeAirAction : IntakeAir {
                in atmosphericAir;
                out chamberAir;
            }
            
            then action pushHandle {
                out handlePos : LengthValue;
            }
            
            then action compressAirAction : CompressAir {
                in pistonPosition = pushHandle.handlePos;
                in chamberVolume;
                out compressedAir;
                out outletPressure;
            }
            
            then decide;
                if compressAirAction.outletPressure > 101325.0[Pa] then deliverAir;
                if compressAirAction.outletPressure <= 101325.0[Pa] then continuePumping;
            
            action deliverAir : TransferAir {
                in sourceAir = compressAirAction.compressedAir;
                out deliveredAir;
            }
            
            then continuePumping;
        }
        
        requirement def PumpPerformanceReq {
            doc /* The bicycle pump shall deliver air at a minimum pressure of 400 kPa. */
            
            subject bicyclePump : BicyclePump;
            
            require constraint {
                bicyclePump.chamber.currentPressure >= 400000.0[Pa]
            }
        }
        
        requirement def PumpStrokeReq {
            doc /* The pump piston shall have a minimum stroke length of 200 mm. */
            
            subject pumpPiston : Piston;
            
            require constraint {
                pumpPiston.maxStroke >= 200.0[mm]
            }
        }
        
        requirement def ValveOperationReq {
            doc /* Intake and outlet valves shall not be open simultaneously. */
            
            subject pump : BicyclePump;
            
            require constraint {
                not (pump.intakeValve.isOpen and pump.outletValve.isOpen)
            }
        }
    }
    
    package Usages {
        part pumpingSystem {
            part atmosphere : AtmosphericSource {
                port :>> airSupply {
                    out item :>> airOut : Air {
                        attribute :>> pressure = 101325.0[Pa];
                        attribute :>> temperature = 293.15[K];
                        attribute :>> volume = 1.0[m^3];
                    }
                }
            }
            
            part bicyclePump : BicyclePump {
                perform action pumpingCycle : PumpingCycle;
            }
            
            flow of air : Air 
                from atmosphere.airSupply.airOut 
                to bicyclePump.atmospherePort.airOut;
            
            flow of air : Air
                from bicyclePump.intakeValve.outPort.airOut
                to bicyclePump.chamber.airInPort.airOut;
            
            flow of air : Air
                from bicyclePump.chamber.airOutPort.airOut
                to bicyclePump.outletValve.inPort.airOut;
            
            flow of air : Air
                from bicyclePump.outletValve.outPort.airOut
                to bicyclePump.hose.inPort.airOut;
            
            flow of air : Air
                from bicyclePump.hose.outPort.airOut
                to bicyclePump.outputPort.airOut;
            
            part target : InflatableTarget {
                attribute :>> targetPressure = 450000.0[Pa];
                attribute :>> currentVolume = 0.002[m^3];
            }
            
            flow of air : Air
                from bicyclePump.outputPort.airOut
                to target.airInPort.airOut;
            
            flow target.airInPort.airOut to target.storedAir;
            
            satisfy pumpPerformanceReq : PumpPerformanceReq by bicyclePump;
            satisfy pumpStrokeReq : PumpStrokeReq by bicyclePump.piston;
            satisfy valveOperationReq : ValveOperationReq by bicyclePump;
        }
    }
}
