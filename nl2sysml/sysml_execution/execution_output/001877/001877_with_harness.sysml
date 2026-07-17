package 'Savery Steam Pump System' {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    
    attribute def ValveState {
        attribute isOpen : Boolean;
    }
    
    attribute def VesselCondition {
        attribute containsSteam : Boolean;
        attribute containsWater : Boolean;
        attribute isUnderVacuum : Boolean;
    }
    
    item def Water {
        attribute volume : VolumeValue;
        attribute temperature : ThermodynamicTemperatureValue;
    }
    
    item def Steam {
        attribute pressure : PressureValue;
        attribute temperature : ThermodynamicTemperatureValue;
        attribute mass : MassValue;
    }
    
    port def SteamPort {
        out item steam : Steam;
    }
    
    port def WaterPort {
        inout item water : Water;
    }
    
    part def Boiler {
        attribute operatingPressure : PressureValue;
        attribute waterLevel : LengthValue;
        attribute fuelRate : PowerValue;
        out port steamSupply : SteamPort;
    }
    
    part def ReceivingVessel {
        attribute capacity : VolumeValue;
        attribute currentCondition : VesselCondition;
        in port steamInlet : SteamPort;
        in port waterIntake : WaterPort;
        out port waterDischarge : WaterPort;
        in port condensateSpray : WaterPort;
    }
    
    part def SteamValve {
        attribute valveState : ValveState;
        in port inlet : SteamPort;
        out port outlet : SteamPort;
    }
    
    part def WaterValve {
        attribute valveState : ValveState;
        in port inlet : WaterPort;
        out port outlet : WaterPort;
    }
    
    part def SupplyPipe {
        attribute length : LengthValue;
        attribute diameter : LengthValue;
        in port source : WaterPort;
        out port destination : WaterPort;
    }
    
    part def DeliveryPipe {
        attribute deliveryHeight : LengthValue;
        attribute diameter : LengthValue;
        in port source : WaterPort;
        out port destination : WaterPort;
    }
    
    part def WaterSource {
        attribute depth : LengthValue;
        attribute availableVolume : VolumeValue;
        out port supply : WaterPort;
    }
    
    part def CoolingWaterSupply {
        attribute temperature : ThermodynamicTemperatureValue;
        out port coldWater : WaterPort;
    }
    
    action def GenerateSteam {
        in fuelInput : PowerValue;
        in waterSupply : VolumeValue;
        out steamOutput : Steam;
    }
    
    action def OpenValve {
        inout valveState : ValveState;
    }
    
    action def CloseValve {
        inout valveState : ValveState;
    }
    
    action def AdmitSteamToVessel {
        in steamPressure : PressureValue;
        inout vesselCondition : VesselCondition;
        out vesselPressurized : Boolean;
    }
    
    action def ExpelWaterByPressure {
        in steamPressure : PressureValue;
        in waterVolume : VolumeValue;
        in deliveryHeight : LengthValue;
        out waterExpelled : VolumeValue;
    }
    
    action def CondenseSteamInVessel {
        in coldWaterFlow : Boolean;
        inout vesselCondition : VesselCondition;
        out vacuumCreated : Boolean;
    }
    
    action def DrawWaterByVacuum {
        in vacuumStrength : Boolean;
        in sourceDepth : LengthValue;
        out waterDrawn : VolumeValue;
        inout vesselCondition : VesselCondition;
    }
    
    action def SaveryPumpingCycle {
        in boilerPressure : PressureValue;
        in sourceDepth : LengthValue;
        in deliveryHeight : LengthValue;
        out waterPumped : VolumeValue;
        
        private attribute vesselState : VesselCondition;
        private attribute steamValvePosition : ValveState;
        private attribute intakeValvePosition : ValveState;
        private attribute dischargeValvePosition : ValveState;
        private attribute condensateValvePosition : ValveState;
        private attribute waterInVessel : VolumeValue;
        
        first start;
        
        then action initializeValves {
            action closeSteam : CloseValve { inout valveState = steamValvePosition; }
            action closeIntake : CloseValve { inout valveState = intakeValvePosition; }
            action closeDischarge : CloseValve { inout valveState = dischargeValvePosition; }
            action closeCondensate : CloseValve { inout valveState = condensateValvePosition; }
        }
        
        then action steamAdmissionPhase {
            action openSteamValve : OpenValve { inout valveState = steamValvePosition; }
            then action admitSteam : AdmitSteamToVessel {
                in steamPressure = boilerPressure;
                inout vesselCondition = vesselState;
                out vesselPressurized;
            }
            then action closeSteamValve : CloseValve { inout valveState = steamValvePosition; }
        }
        
        then action waterExpulsionPhase {
            action openDischargeValve : OpenValve { inout valveState = dischargeValvePosition; }
            then action expelWater : ExpelWaterByPressure {
                in steamPressure = boilerPressure;
                in waterVolume = waterInVessel;
                in deliveryHeight = deliveryHeight;
                out waterExpelled;
            }
            then assign waterInVessel := 0.0;
            then action closeDischargeValve : CloseValve { inout valveState = dischargeValvePosition; }
        }
        
        then action steamCondensationPhase {
            action openCondensateValve : OpenValve { inout valveState = condensateValvePosition; }
            then action condenseSteam : CondenseSteamInVessel {
                in coldWaterFlow = true;
                inout vesselCondition = vesselState;
                out vacuumCreated;
            }
            then action closeCondensateValve : CloseValve { inout valveState = condensateValvePosition; }
        }
        
        then action waterIntakePhase {
            action openIntakeValve : OpenValve { inout valveState = intakeValvePosition; }
            then action drawWater : DrawWaterByVacuum {
                in vacuumStrength = steamCondensationPhase.condenseSteam.vacuumCreated;
                in sourceDepth = sourceDepth;
                out waterDrawn;
                inout vesselCondition = vesselState;
            }
            then assign waterInVessel := drawWater.waterDrawn;
            then action closeIntakeValve : CloseValve { inout valveState = intakeValvePosition; }
        }
        
        then assign waterPumped := waterExpulsionPhase.expelWater.waterExpelled;
        then done;
    }
    
    action def OperateSaveryPump {
        in operatingPressure : PressureValue;
        in pumpingDepth : LengthValue;
        in dischargeHeight : LengthValue;
        out totalWaterPumped : VolumeValue;
        
        first start;
        then merge continuousCycle;
        then action executeCycle : SaveryPumpingCycle {
            in boilerPressure = operatingPressure;
            in sourceDepth = pumpingDepth;
            in deliveryHeight = dischargeHeight;
            out waterPumped;
        }
        then assign totalWaterPumped := totalWaterPumped + executeCycle.waterPumped;
        then continuousCycle;
    }
    
    part saveryPumpSystem {
        attribute mineDepth : LengthValue;
        attribute dischargeElevation : LengthValue;
        attribute maxBoilerPressure : PressureValue;
        
        part steamBoiler : Boiler {
            attribute operatingPressure : PressureValue;
            attribute waterLevel : LengthValue;
            attribute fuelRate : PowerValue;
        }
        
        part receivingVessel : ReceivingVessel {
            attribute capacity : VolumeValue;
            attribute currentCondition : VesselCondition;
        }
        
        part steamAdmissionValve : SteamValve {
            attribute valveState : ValveState;
        }
        
        part waterIntakeValve : WaterValve {
            attribute valveState : ValveState;
        }
        
        part waterDeliveryValve : WaterValve {
            attribute valveState : ValveState;
        }
        
        part condensateInjectionValve : WaterValve {
            attribute valveState : ValveState;
        }
        
        part mineWater : WaterSource {
            attribute depth : LengthValue;
            attribute availableVolume : VolumeValue;
        }
        
        part supplyPipe : SupplyPipe {
            attribute length : LengthValue;
            attribute diameter : LengthValue;
        }
        
        part deliveryPipe : DeliveryPipe {
            attribute deliveryHeight : LengthValue;
            attribute diameter : LengthValue;
        }
        
        part coolingSupply : CoolingWaterSupply {
            attribute temperature : ThermodynamicTemperatureValue;
        }
        
        connect steamBoiler.steamSupply to steamAdmissionValve.inlet;
        connect steamAdmissionValve.outlet to receivingVessel.steamInlet;
        
        connect mineWater.supply to supplyPipe.source;
        connect supplyPipe.destination to waterIntakeValve.inlet;
        connect waterIntakeValve.outlet to receivingVessel.waterIntake;
        
        connect receivingVessel.waterDischarge to waterDeliveryValve.inlet;
        connect waterDeliveryValve.outlet to deliveryPipe.source;
        
        connect coolingSupply.coldWater to condensateInjectionValve.inlet;
        connect condensateInjectionValve.outlet to receivingVessel.condensateSpray;
        
        perform action pumpOperation : OperateSaveryPump {
            in operatingPressure = maxBoilerPressure;
            in pumpingDepth = mineDepth;
            in dischargeHeight = dischargeElevation;
            out totalWaterPumped;
        }
    }
    
    requirement def PrimaryPumpingFunction {
        doc /* The Savery pump shall lift water from a low source to an elevated discharge point using alternating steam pressure and vacuum. */
    }
    
    requirement def SteamPressureCapability {
        doc /* The boiler shall generate sufficient steam pressure to force water up the delivery pipe against gravity. */
        require constraint { saveryPumpSystem.steamBoiler.operatingPressure > 0.0 }
    }
    
    requirement def VacuumGenerationCapability {
        doc /* The system shall create vacuum by condensing steam to draw water from the source into the receiving vessel. */
    }
    
    requirement def CyclicOperationRequirement {
        doc /* The pump shall operate in continuous cycles of steam admission, water expulsion, steam condensation, and water intake. */
    }
    
    requirement def SafetyRequirement {
        doc /* The boiler pressure shall not exceed safe operating limits to prevent vessel rupture. */
        require constraint { saveryPumpSystem.steamBoiler.operatingPressure <= saveryPumpSystem.maxBoilerPressure }
    }
    
    requirement saveryPumpRequirements {
        doc /* The Savery steam pump system shall pump water from mines by using steam pressure to expel water and vacuum to draw water in repeating cycles. */
        
        require requirement primaryFunctionReq : PrimaryPumpingFunction;
        require requirement steamPressureReq : SteamPressureCapability;
        require requirement vacuumGenerationReq : VacuumGenerationCapability;
        require requirement cyclicOperationReq : CyclicOperationRequirement;
        require requirement safetyReq : SafetyRequirement;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    private import 'Savery Steam Pump System'::*;
}
