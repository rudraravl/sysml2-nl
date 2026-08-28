package FirePumpingSubsystem {
    private import ISQ::*;
    private import ScalarValues::*;
    
    item def Water;
    
    attribute def StartCmd;
    attribute def StopCmd;
    attribute def ResetCmd;
    attribute def PrimingDone;
    attribute def ShutdownDone;
    attribute def AlarmSignal;
    attribute def MotorStart;
    attribute def MotorStop;
    
    port def FluidPort {
        attribute pressure : PressureValue;
        attribute flowRate : VolumeFlowRateValue;
        ref item water : Water;
    }
    
    port def MechanicalPort {
        attribute torque : TorqueValue;
        attribute speed : Real;
    }
    
    port def PressureDataPort {
        attribute reading : PressureValue;
    }
    
    port def FlowDataPort {
        attribute reading : VolumeFlowRateValue;
    }
    
    port def CommandPort {
        attribute command : String;
    }
    
    port def AlarmPort {
        attribute signal : AlarmSignal;
    }
    
    port def MotorControlPort {
        attribute command : String;
    }
    
    action def GeneratePressure {
        in waterIn : Water;
        out waterOut : Water;
    }
    
    action def DistributeWater {
        in waterIn : Water;
        out waterOut1 : Water;
        out waterOut2 : Water;
    }
    
    part def WaterSupplySource {
        out port waterPort : FluidPort;
        attribute capacity : VolumeValue;
    }
    
    part def Motor {
        in port controlPort : MotorControlPort;
        out port mechanicalPort : MechanicalPort;
        attribute powerState : Boolean := false;
    }
    
    part def Shaft {
        in port inMech : MechanicalPort;
        out port outMech : MechanicalPort;
    }
    
    part def Impeller {
        in port mechPort : MechanicalPort;
        in port waterIn : FluidPort;
        out port waterOut : FluidPort;
    }
    
    part def Casing {
        attribute volume : VolumeValue;
    }
    
    part def FirePump {
        in port suctionPort : FluidPort;
        out port dischargePort : FluidPort;
        in port controlPort : MotorControlPort;
        
        part motor : Motor;
        part shaft : Shaft;
        part impeller : Impeller;
        part casing : Casing;
        
        connect motor.mechanicalPort to shaft.inMech;
        connect shaft.outMech to impeller.mechPort;
        connect suctionPort to impeller.waterIn;
        connect impeller.waterOut to dischargePort;
        
        action generatePressure : GeneratePressure;
        attribute startupTime : TimeValue := 5;
        attribute continuousOperation : Boolean := true;
    }
    
    part def DischargeManifold {
        in port inletPort : FluidPort;
        out port outletPort1 : FluidPort;
        out port outletPort2 : FluidPort;
        action distribute : DistributeWater;
    }
    
    part def PressureSensor {
        in port fluidPort : FluidPort;
        out port dataPort : PressureDataPort;
        attribute currentPressure : PressureValue;
        action sense {
            out value : PressureValue;
        }
    }
    
    part def FlowMeter {
        in port fluidPort : FluidPort;
        out port dataPort : FlowDataPort;
        attribute currentFlowRate : VolumeFlowRateValue;
        action sense {
            out value : VolumeFlowRateValue;
        }
    }
    
    part def OperatorPanel {
        out port commandPort : CommandPort;
    }
    
    part def PumpController {
        in port suctionSensorPort : PressureDataPort;
        in port dischargeSensorPort : PressureDataPort;
        in port flowMeterPort : FlowDataPort;
        in port commandPort : CommandPort;
        out port motorControlPort : MotorControlPort;
        out port alarmPort : AlarmPort;
        
        attribute targetPressure : PressureValue;
        attribute minSuctionPressure : PressureValue;
        attribute maxDischargePressure : PressureValue;
        
        state controllerStates {
            entry; then off;
            state off;
            transition off_to_priming
                first off
                accept StartCmd
                do send new MotorStart() via motorControlPort
                then priming;
            state priming;
            transition priming_to_running
                first priming
                accept PrimingDone
                then running;
            state running;
            transition running_to_alarm_low_suction
                first running
                accept reading : PressureValue via suctionSensorPort
                if reading < minSuctionPressure
                do send new AlarmSignal() via alarmPort
                then alarmShutdown;
            transition running_to_alarm_high_discharge
                first running
                accept reading : PressureValue via dischargeSensorPort
                if reading > maxDischargePressure
                do send new AlarmSignal() via alarmPort
                then alarmShutdown;
            transition running_to_stop
                first running
                accept StopCmd
                do send new MotorStop() via motorControlPort
                then controlledShutdown;
            state alarmShutdown;
            transition alarm_to_off
                first alarmShutdown
                accept ResetCmd
                then off;
            state controlledShutdown;
            transition stop_to_off
                first controlledShutdown
                accept ShutdownDone
                then off;
        }
    }
    
    requirement def FirePumpPerformance {
        doc /* The pump must start up quickly. */
        subject fp : FirePump;
        constraint { fp.startupTime <= 10 }
    }
    
    requirement def FirePumpReliability {
        doc /* The pump must operate continuously when needed. */
        subject fp : FirePump;
        constraint { fp.continuousOperation == true }
    }
    
    part def FirePumpingSubsystem {
        part waterSupply : WaterSupplySource;
        part firePump : FirePump;
        part manifold : DischargeManifold;
        part controller : PumpController;
        part suctionSensor : PressureSensor;
        part dischargeSensor : PressureSensor;
        part flowMeter : FlowMeter;
        part operatorPanel : OperatorPanel;
        
        connect waterSupply.waterPort to firePump.suctionPort;
        connect firePump.dischargePort to manifold.inletPort;
        
        connect waterSupply.waterPort to suctionSensor.fluidPort;
        connect suctionSensor.dataPort to controller.suctionSensorPort;
        
        connect firePump.dischargePort to dischargeSensor.fluidPort;
        connect dischargeSensor.dataPort to controller.dischargeSensorPort;
        
        connect firePump.dischargePort to flowMeter.fluidPort;
        connect flowMeter.dataPort to controller.flowMeterPort;
        
        connect operatorPanel.commandPort to controller.commandPort;
        connect controller.motorControlPort to firePump.controlPort;
        
        requirement pumpPerformance : FirePumpPerformance {
            subject fp = firePump;
        }
        
        requirement pumpReliability : FirePumpReliability {
            subject fp = firePump;
        }
    }
}
