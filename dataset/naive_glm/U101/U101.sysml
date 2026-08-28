package PenisClampSystem {
    import ScalarValues::*;
    
    unit Pa;
    unit mL_per_s;
    unit h;
    
    value def Pressure :> Real { unit Pa; }
    value def FlowRate :> Real { unit mL_per_s; }
    value def Duration :> Real { unit h; }
    value def LeverPosition :> Integer;
    
    item def Urine;
    
    port def PressureSignalPort {
        out pressure : Pressure;
    }
    port def FlowSignalPort {
        out flowRate : FlowRate;
    }
    port def SafetyAlertPort {
        out alert : Boolean;
    }
    port def LeverCommandPort {
        out position : LeverPosition;
    }
    
    requirement def SafetyLimits {
        subject monitor : SafetyMonitor;
        requirement maxPressure {
            subject monitor;
            constraint { monitor.appliedPressure <= 45000 [Pa] }
        }
        requirement maxDuration {
            subject monitor;
            constraint { monitor.continuousUseDuration <= 2 [h] }
        }
    }
    
    part def AdjustmentLever {
        attribute currentPosition : LeverPosition = 0;
        out port leverCmd : LeverCommandPort;
        
        action setLever(in pos : LeverPosition) {
            assign currentPosition = pos;
        }
    }
    
    part def CompressionMechanism {
        in port leverCmd : LeverCommandPort;
        in port safetyCmd : SafetyAlertPort;
        out port pressureSignal : PressureSignalPort;
        
        attribute targetPressure : Pressure;
        attribute appliedPressure : Pressure;
        attribute targetAchieved : Boolean = false;
        
        action applyPressure(in target : Pressure) {
            // apply pressure
        }
        action releasePressure {
            // release
        }
    }
    
    part def PressurePad {
        in port pressureSignal : PressureSignalPort;
        // distributes pressure evenly
    }
    
    part def FlowSensor {
        in item urine : Urine;
        out port flowSignal : FlowSignalPort;
        attribute flowRate : FlowRate;
    }
    
    part def SafetyMonitor {
        in port pressureSignal : PressureSignalPort;
        in port flowSignal : FlowSignalPort;
        out port safetyAlert : SafetyAlertPort;
        
        attribute appliedPressure : Pressure;
        attribute continuousUseDuration : Duration;
        attribute maxPressure : Pressure = 45000 [Pa];
        attribute maxDuration : Duration = 2 [h];
        attribute limitExceeded : Boolean = false;
        
        satisfy SafetyLimits;
        
        action monitorSafety {
            // check pressure and duration
        }
    }
    
    part def PenisClampDevice {
        attribute userPosition : Boolean;
        attribute userActivate : Boolean;
        attribute userRelease : Boolean;
        
        part adjustmentLever : AdjustmentLever;
        part compressionMechanism : CompressionMechanism;
        part pressurePad : PressurePad;
        part flowSensor : FlowSensor;
        part safetyMonitor : SafetyMonitor;
        
        connection leverToCompression connect adjustmentLever.leverCmd to compressionMechanism.leverCmd;
        connection compressionToPad connect compressionMechanism.pressureSignal to pressurePad.pressureSignal;
        connection compressionToMonitor connect compressionMechanism.pressureSignal to safetyMonitor.pressureSignal;
        connection flowToMonitor connect flowSensor.flowSignal to safetyMonitor.flowSignal;
        connection monitorToCompression connect safetyMonitor.safetyAlert to compressionMechanism.safetyCmd;
        
        state def DeviceLifecycle {
            entry;
            
            state idle;
            state positioning;
            state compressing;
            state active;
            state emergency;
            
            transition t1 first idle if userPosition then positioning;
            transition t2 first positioning if userActivate then compressing;
            transition t3 first compressing if compressionMechanism.targetAchieved then active;
            transition t4 first active if userRelease then idle;
            transition t5 first active if safetyMonitor.limitExceeded then emergency;
            transition t6 first emergency then idle;
        }
        
        exhibit state DeviceLifecycle;
    }
}
