package WangensteenSuctionSystem {
    attribute def Pressure :> ScalarValues::Real;
    attribute def Volume :> ScalarValues::Real;
    attribute def Duration :> ScalarValues::Real;
    
    item def GastricFluid {
        attribute volume : Volume;
    }
    item def Air;
    item def ControlCommand;
    item def StartCommand :> ControlCommand;
    item def StopCommand :> ControlCommand;
    item def SetPressureCommand :> ControlCommand {
        attribute pressure : Pressure;
    }
    item def PumpCommand :> ControlCommand {
        attribute on : ScalarValues::Boolean;
    }
    item def ModeCommand :> ControlCommand {
        attribute mode : ScalarValues::String;
    }
    item def PressureReading {
        attribute pressure : Pressure;
    }
    item def BottleLevel {
        attribute level : Volume;
    }
    item def AlarmSignal {
        attribute reason : ScalarValues::String;
    }
    
    port def FluidPort {
        attribute pressure : Pressure;
        out item fluid : GastricFluid;
        out item gas : Air;
    }
    port def ControlPort {
        out item command : ControlCommand;
    }
    port def ReadingPort {
        out item reading : PressureReading;
    }
    port def LevelPort {
        out item reading : BottleLevel;
    }
    port def AlarmPort {
        out item alarm : AlarmSignal;
    }
    port def UserPort {
        in item command : ControlCommand;
    }
    port def ModePort {
        in item mode : ModeCommand;
    }
    
    part def NasogastricTube {
        port patientEnd : ~FluidPort;
        port systemEnd : FluidPort;
    }
    
    part def CollectionBottle {
        port inlet : ~FluidPort;
        port outlet : FluidPort;
        port levelOut : LevelPort;
        attribute currentVolume : Volume = 0;
        attribute capacity : Volume = 1000;
    }
    
    part def WaterSealChamber {
        port inlet : ~FluidPort;
        port outlet : FluidPort;
        attribute waterLevel : Volume = 10;
    }
    
    part def VacuumPump {
        port suctionPort : ~FluidPort;
        port controlIn : ~ControlPort;
    }
    
    part def SuctionRegulator {
        port systemSide : ~FluidPort;
        port pumpSide : FluidPort;
        port controlIn : ~ControlPort;
        attribute regulatedPressure : Pressure;
    }
    
    part def PressureGauge {
        port sensePort : ~FluidPort;
        port displayOut : ReadingPort;
        attribute currentPressure : Pressure;
    }
    
    part def SafetyValve {
        port sensePort : ~FluidPort;
        port ventPort : FluidPort;
        attribute threshold : Pressure = -150;
    }
    
    part def ControlUnit {
        attribute desiredPressure : Pressure = -80;
        attribute minPressure : Pressure = -120;
        attribute maxPressure : Pressure = -20;
        attribute mode : ScalarValues::String = "continuous";
        attribute intermittentOnTime : Duration = 10;
        attribute intermittentOffTime : Duration = 5;
        port fromGauge : ~ReadingPort;
        port fromBottle : ~LevelPort;
    }
    
    part def WangensteenSystem {
        port userIn : UserPort;
        port modeIn : ModePort;
        port alarmOut : AlarmPort;
        
        part nasogastricTube : NasogastricTube;
        part collectionBottle : CollectionBottle;
        part waterSeal : WaterSealChamber;
        part vacuumPump : VacuumPump;
        part regulator : SuctionRegulator;
        part pressureGauge : PressureGauge;
        part safetyValve : SafetyValve;
        part controlUnit : ControlUnit;
        
        connect nasogastricTube.systemEnd to collectionBottle.inlet;
        connect collectionBottle.outlet to waterSeal.inlet;
        connect waterSeal.outlet to regulator.systemSide;
        connect regulator.pumpSide to vacuumPump.suctionPort;
        connect waterSeal.outlet to pressureGauge.sensePort;
        connect waterSeal.outlet to safetyValve.sensePort;
        connect pressureGauge.displayOut to controlUnit.fromGauge;
        connect collectionBottle.levelOut to controlUnit.fromBottle;
        
        state def SystemState {
            in system : WangensteenSystem;
            entry; then off;
            state off;
            transition first off
                accept start : StartCommand via system.userIn
                then priming;
            state priming;
            transition first priming then operating;
            state operating {
                entry; then continuous;
                state continuous;
                state intermittent;
                transition first continuous
                    accept modeCmd : ModeCommand via system.modeIn
                    if modeCmd.mode == "intermittent"
                    then intermittent;
                transition first intermittent
                    accept modeCmd : ModeCommand via system.modeIn
                    if modeCmd.mode == "continuous"
                    then continuous;
            }
            transition first operating
                if system.collectionBottle.currentVolume >= system.collectionBottle.capacity
                then alarm;
            transition first operating
                if system.pressureGauge.currentPressure < system.controlUnit.minPressure
                then alarm;
            transition first operating
                if system.pressureGauge.currentPressure > system.controlUnit.maxPressure
                then alarm;
            transition first operating
                accept stop : StopCommand via system.userIn
                then off;
            state alarm;
            transition first alarm
                accept stop : StopCommand via system.userIn
                then off;
        }
        
        state systemState : SystemState {
            in system = this;
        }
    }
    
    requirement def SafePressureRange {
        doc /* The suction pressure shall be maintained within a safe therapeutic range. */
    }
    requirement def BottleFullAlarm {
        doc /* An alarm shall activate when the collection bottle reaches capacity. */
    }
    requirement def BackflowPrevention {
        doc /* The water seal chamber shall prevent air from being drawn back into the patient. */
    }
    requirement def ModeSupport {
        doc /* The system shall support continuous and intermittent suction modes. */
    }
    
    requirement safePressureReq : SafePressureRange;
    requirement bottleFullReq : BottleFullAlarm;
    requirement backflowReq : BackflowPrevention;
    requirement modeReq : ModeSupport;
    
    satisfy safePressureReq by WangensteenSystem;
    satisfy bottleFullReq by WangensteenSystem;
    satisfy backflowReq by WaterSealChamber;
    satisfy modeReq by WangensteenSystem;
}
