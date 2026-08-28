package 'Savery Steam Pump Model' {
    private import ScalarValues::Boolean;
    private import ISQ::*;
    
    alias Pressure for PressureValue;
    alias Volume for VolumeValue;
    
    item def Steam;
    item def Water;
    
    port def SteamPort {
        out item steam : Steam;
    }
    port def WaterPort {
        out item water : Water;
    }
    
    attribute def VesselEmptySignal;
    attribute def VacuumCreatedSignal;
    attribute def VesselFullSignal;
    
    action def 'Expel Water' {
        in steamPressure : Pressure;
        out expelledVolume : Volume;
    }
    action def 'Condense Steam' {
        in coldWaterVolume : Volume;
        out vacuumPressure : Pressure;
    }
    action def 'Intake Water' {
        in vacuumPressure : Pressure;
        out intakeVolume : Volume;
    }
    action def 'Operate Pump' {
        out pumpedVolume : Volume;
    }
    
    state def PumpCycle {
        state 'Water Expulsion';
        state 'Steam Condensation';
        state 'Water Intake';
        transition from 'Water Expulsion' to 'Steam Condensation' on VesselEmptySignal;
        transition from 'Steam Condensation' to 'Water Intake' on VacuumCreatedSignal;
        transition from 'Water Intake' to 'Water Expulsion' on VesselFullSignal;
    }
    
    part def Boiler {
        attribute steamPressure : Pressure;
        port steamOut : SteamPort;
    }
    
    part def ReceivingVessel {
        attribute capacity : Volume;
        attribute currentVolume : Volume;
        in steamIn : SteamPort;
        in coldWaterIn : WaterPort;
        in mineWaterIn : WaterPort;
        out dischargeOut : WaterPort;
    }
    
    part def Valve {
        attribute isOpen : Boolean;
    }
    
    part def SteamValve :> Valve {
        in steamIn : SteamPort;
        out steamOut : SteamPort;
    }
    
    part def WaterValve :> Valve {
        in waterIn : WaterPort;
        out waterOut : WaterPort;
    }
    
    part def OneWayValve :> WaterValve {
    }
    
    part def Pipe {
        in pipeIn : WaterPort;
        out pipeOut : WaterPort;
    }
    
    part def WaterSource {
        out sourceOut : WaterPort;
    }
    
    part def DeliveryPoint {
        in intake : WaterPort;
    }
    
    part def SaveryPump {
        in mineWaterIntake : WaterPort;
        in coldWaterIntake : WaterPort;
        out waterDelivery : WaterPort;
        
        part boiler : Boiler;
        part steamValve : SteamValve;
        part vessel : ReceivingVessel;
        part coldWaterValve : WaterValve;
        part dischargeValve : OneWayValve;
        part supplyPipe : Pipe;
        part deliveryPipe : Pipe;
        
        connect boiler.steamOut to steamValve.steamIn;
        connect steamValve.steamOut to vessel.steamIn;
        
        connect coldWaterIntake to coldWaterValve.waterIn;
        connect coldWaterValve.waterOut to vessel.coldWaterIn;
        
        connect mineWaterIntake to supplyPipe.pipeIn;
        connect supplyPipe.pipeOut to vessel.mineWaterIn;
        
        connect vessel.dischargeOut to dischargeValve.waterIn;
        connect dischargeValve.waterOut to deliveryPipe.pipeIn;
        connect deliveryPipe.pipeOut to waterDelivery;
        
        state pumpCycle : PumpCycle;
        
        action operatePump : 'Operate Pump' {
            out pumpedVolume : Volume;
            loop {
                action 'expel water' : 'Expel Water';
                action 'condense steam' : 'Condense Steam';
                action 'intake water' : 'Intake Water';
                first 'expel water' then 'condense steam';
                first 'condense steam' then 'intake water';
                first 'intake water' then 'expel water';
            }
        }
    }
    
    requirement def PumpWaterFromMine {
        subject pump : SaveryPump;
        doc /* The Savery pump shall remove water from a flooded mine using a four-stage steam and vacuum cycle. */
    }
    
    part saverySystem : SaveryPump;
    part mine : WaterSource;
    part coldWaterSource : WaterSource;
    part delivery : DeliveryPoint;
    
    connect mine.sourceOut to saverySystem.mineWaterIntake;
    connect coldWaterSource.sourceOut to saverySystem.coldWaterIntake;
    connect saverySystem.waterDelivery to delivery.intake;
    
    requirement pumpWaterRequirement : PumpWaterFromMine {
        subject pump = saverySystem;
    }
}
