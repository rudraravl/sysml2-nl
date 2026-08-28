package DishwasherModel {
    private import ScalarValues::*;
    private import ISQ::*;
    
    package Definitions {
        private import ScalarValues::*;
        private import ISQ::*;
        
        item def Water;
        item def Detergent;
        
        attribute def StartSignal;
        attribute def StopSignal;
        
        port def WaterPort {
            ref water : Water;
        }
        port def DrainPort {
            ref wasteWater : Water;
        }
        port def ControlPort {
            in signal : Real;
        }
        port def DetergentPort {
            ref detergent : Detergent;
        }
        port def SensorPort {
            out temp : Real;
            out level : Real;
        }
        port def DoorPort {
            in lockCmd : Boolean;
            out lockedStatus : Boolean;
        }
        
        action def FillWater;
        action def HeatWater;
        action def CirculateWater;
        action def DrainWater;
        action def ReleaseDetergent;
        action def LockDoor;
        action def UnlockDoor;
        action def DryDishes;
        
        part def SprayArm {
            attribute rotationSpeed : Real;
        }
        
        part def FilterAssembly {
            attribute meshSize : Real;
        }
        
        part def WashChamber {
            attribute capacity : Real;
            port waterInlet : WaterPort;
            port waterOutlet : WaterPort;
            port sprayPort : WaterPort;
            port drainPort : DrainPort;
            port detergentInlet : DetergentPort;
            part upperSprayArm : SprayArm;
            part lowerSprayArm : SprayArm;
            part meshFilter : FilterAssembly;
        }
        
        part def WaterInletValve {
            port inlet : WaterPort;
            port outlet : WaterPort;
        }
        
        part def HeatingElement {
            attribute powerRating : Real;
        }
        
        part def CirculationPump {
            port inlet : WaterPort;
            port outlet : WaterPort;
            attribute flowRate : Real;
        }
        
        part def DrainPump {
            port inlet : DrainPort;
            port outlet : DrainPort;
        }
        
        part def DetergentDispenser {
            port dispensePort : DetergentPort;
        }
        
        part def TemperatureSensor {
            port sensorPort : SensorPort;
        }
        
        part def WaterLevelSensor {
            port sensorPort : SensorPort;
        }
        
        part def DoorLatch {
            attribute isClosed : Boolean;
            attribute isLocked : Boolean;
            port doorPort : DoorPort;
        }
        
        part def ControlPanel {
            port controlPort : ControlPort;
        }
        
        part def ControlModule {
            port sensorIn : SensorPort;
            port userIn : ControlPort;
            port doorCmd : DoorPort;
            port detergentCmd : DetergentPort;
        }
        
        state def CycleStates;
        
        part def Dishwasher {
            attribute cleaningEfficiency : Real;
            attribute totalWaterUsed : Real;
            attribute sanitizeTemp : Real;
            attribute doorLockedDuringWet : Boolean;
            
            port waterInlet : WaterPort;
            port waterOutlet : DrainPort;
            port userInterface : ControlPort;
            
            part chamber : WashChamber;
            part inletValve : WaterInletValve;
            part heater : HeatingElement;
            part circPump : CirculationPump;
            part drainPump : DrainPump;
            part dispenser : DetergentDispenser;
            part tempSensor : TemperatureSensor;
            part levelSensor : WaterLevelSensor;
            part latch : DoorLatch;
            part controller : ControlModule;
            part panel : ControlPanel;
            
            perform action fillColdWater : FillWater;
            perform action sprayColdWater : CirculateWater;
            perform action drainPreWash : DrainWater;
            perform action fillMainWash : FillWater;
            perform action heatMainWash : HeatWater;
            perform action releaseDetergentAction : ReleaseDetergent;
            perform action sprayMainWash : CirculateWater;
            perform action drainMainWash : DrainWater;
            perform action fillRinse : FillWater;
            perform action heatRinse : HeatWater;
            perform action sprayRinse : CirculateWater;
            perform action drainRinse : DrainWater;
            perform action dryDishesAction : DryDishes;
            perform action lockDoorAction : LockDoor;
            perform action unlockDoorAction : UnlockDoor;
            
            exhibit state cycleStates : CycleStates {
                entry action initial { }
                transition initial then Idle;
                
                state Idle;
                transition 'Idle-PreWash'
                    first Idle
                    accept StartSignal
                    if latch.isClosed
                    do lockDoorAction
                    then PreWash;
                
                state PreWash {
                    entry fillColdWater;
                    do sprayColdWater;
                    exit drainPreWash;
                }
                transition 'PreWash-MainWash'
                    first PreWash
                    then MainWash;
                
                state MainWash {
                    entry {
                        fillMainWash;
                        heatMainWash;
                        releaseDetergentAction;
                    }
                    do sprayMainWash;
                    exit drainMainWash;
                }
                transition 'MainWash-Rinse'
                    first MainWash
                    then Rinse;
                
                state Rinse {
                    entry {
                        fillRinse;
                        heatRinse;
                    }
                    do sprayRinse;
                    exit drainRinse;
                }
                transition 'Rinse-Drying'
                    first Rinse
                    then Drying;
                
                state Drying {
                    entry dryDishesAction;
                    exit unlockDoorAction;
                }
                transition 'Drying-Idle'
                    first Drying
                    then Idle;
            }
        }
        
        requirement def CleaningEfficiencyReq {
            doc /* The dishwasher shall remove at least 98 percent of soil from dishes. */
            attribute minEfficiency : Real = 0.98;
            subject dishwasher : Dishwasher;
            constraint { dishwasher.cleaningEfficiency >= minEfficiency }
        }
        
        requirement def WaterConservationReq {
            doc /* The dishwasher shall use no more than 15 liters of water per cycle. */
            attribute maxWaterUsage : Real = 15.0;
            subject dishwasher : Dishwasher;
            constraint { dishwasher.totalWaterUsed <= maxWaterUsage }
        }
        
        requirement def SanitizingTempReq {
            doc /* The rinse phase shall achieve a minimum water temperature of 70 degrees Celsius for sanitization. */
            attribute minRinseTemp : Real = 70.0;
            subject dishwasher : Dishwasher;
            constraint { dishwasher.sanitizeTemp >= minRinseTemp }
        }
        
        requirement def DoorLockSafetyReq {
            doc /* The door shall remain locked during all wet phases of the cycle. */
            subject dishwasher : Dishwasher;
            constraint { dishwasher.doorLockedDuringWet == true }
        }
    }
    
    import Definitions::Dishwasher;
    import Definitions::CycleStates;
    
    package Usages {
        private import Definitions::*;
        
        part dishwasherSystem : Dishwasher {
            connect inletValve.outlet to chamber.waterInlet;
            connect chamber.waterOutlet to circPump.inlet;
            connect circPump.outlet to chamber.sprayPort;
            connect chamber.drainPort to drainPump.inlet;
            connect drainPump.outlet to self.waterOutlet;
            connect dispenser.dispensePort to chamber.detergentInlet;
            connect panel.controlPort to controller.userIn;
            connect tempSensor.sensorPort to controller.sensorIn;
            connect levelSensor.sensorPort to controller.sensorIn;
            connect controller.doorCmd to latch.doorPort;
            connect controller.detergentCmd to dispenser.dispensePort;
            
            flow of Water from inletValve.outlet to chamber.waterInlet;
            flow of Water from chamber.waterOutlet to circPump.inlet;
            flow of Water from circPump.outlet to chamber.sprayPort;
            flow of Water from chamber.drainPort to drainPump.inlet;
            flow of Water from drainPump.outlet to self.waterOutlet;
            flow of Detergent from dispenser.dispensePort to chamber.detergentInlet;
            
            assert constraint { cleaningEfficiency >= 0.98 }
            assert constraint { totalWaterUsed <= 15.0 }
            assert constraint { sanitizeTemp >= 70.0 }
            
            requirement cleaningEfficiencyReq : CleaningEfficiencyReq {
                subject dishwasher = self;
            }
            requirement waterConservationReq : WaterConservationReq {
                subject dishwasher = self;
            }
            requirement sanitizingTempReq : SanitizingTempReq {
                subject dishwasher = self;
            }
            requirement doorLockSafetyReq : DoorLockSafetyReq {
                subject dishwasher = self;
            }
        }
    }
}
