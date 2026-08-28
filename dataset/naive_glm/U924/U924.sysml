package TransmissionControlSystem {
    import ScalarValues::*;
    
    // --- Value Types ---
    value type SpeedValue > Real { unit "km/h"; }
    value type RPMValue > Real { unit "rev/min"; }
    value type ThrottleValue > Real { unit "%"; }
    value type TempValue > Real { unit "degC"; }
    value type PressureValue > Real { unit "bar"; }
    value type DurationValue > Real { unit "s"; }
    
    // --- Enums ---
    enum def DriveMode {
        Eco;
        Sport;
    }
    
    enum def Gear {
        G1;
        G2;
        G3;
        G4;
        G5;
        G6;
        G7;
        G8;
    }
    
    // --- Port Definitions ---
    port def TransmissionCommandPort {
        out targetGear : Gear;
        out pressure : PressureValue;
        out timing : DurationValue;
    }
    
    // --- Sensor Parts ---
    part def VehicleSpeedSensor {
        port speedOut : out SpeedValue;
        attribute value : SpeedValue;
    }
    
    part def EngineSpeedSensor {
        port rpmOut : out RPMValue;
        attribute value : RPMValue;
    }
    
    part def ThrottlePositionSensor {
        port throttleOut : out ThrottleValue;
        attribute value : ThrottleValue;
    }
    
    part def GearSensor {
        port gearOut : out Gear;
        attribute value : Gear;
    }
    
    part def FluidTempSensor {
        port tempOut : out TempValue;
        attribute value : TempValue;
    }
    
    // --- Transmission Parts ---
    part def HydraulicSystem {
        port pressureIn : in PressureValue;
        attribute currentPressure : PressureValue;
    }
    
    part def ClutchActuator {
        port timingIn : in DurationValue;
        port gearIn : in Gear;
        attribute engagedGear : Gear;
        attribute timing : DurationValue;
    }
    
    part def TransmissionAssembly {
        port commandIn : ~TransmissionCommandPort;
        part hydraulics : HydraulicSystem;
        part clutches : ClutchActuator;
        
        connect commandIn.pressure to hydraulics.pressureIn;
        connect commandIn.timing to clutches.timingIn;
        connect commandIn.targetGear to clutches.gearIn;
    }
    
    // --- TCU ---
    part def TransmissionControlUnit {
        port speedIn : in SpeedValue;
        port rpmIn : in RPMValue;
        port throttleIn : in ThrottleValue;
        port gearIn : in Gear;
        port tempIn : in TempValue;
        port commandOut : TransmissionCommandPort;
        
        attribute activeMode : DriveMode;
        attribute lastShiftDuration : DurationValue;
        attribute shiftStartTime : DurationValue;
        
        exhibit stateMachine TCU_OperationalCycle {
            attribute shiftRequired : Boolean;
            attribute shiftConfirmed : Boolean;
            
            state Monitoring {
                entry {
                    shiftRequired = false;
                }
                do {
                    // Continuously read sensor data and monitor fluid temperature
                }
            }
            
            state Analyzing {
                entry {
                    // Analyze driving situation based on activeMode and sensor data
                }
            }
            
            state Calculating {
                entry {
                    // Calculate target gear, hydraulic pressure, and clutch timing
                }
            }
            
            state Executing {
                entry {
                    shiftStartTime = 0.0;
                    // Send shift command via commandOut
                }
            }
            
            state Confirming {
                entry {
                    shiftConfirmed = true;
                    lastShiftDuration = 0.5;
                }
            }
            
            transition from Monitoring to Analyzing {
                when (speedIn > 0.0);
            }
            
            transition from Analyzing to Calculating {
                when (shiftRequired == true);
            }
            
            transition from Analyzing to Monitoring {
                when (shiftRequired == false);
            }
            
            transition from Calculating to Executing;
            
            transition from Executing to Confirming;
            
            transition from Confirming to Monitoring {
                when (shiftConfirmed == true);
            }
        }
    }
    
    // --- Top-level System ---
    part def TCU_System {
        part tcu : TransmissionControlUnit;
        part speedSensor : VehicleSpeedSensor;
        part rpmSensor : EngineSpeedSensor;
        part throttleSensor : ThrottlePositionSensor;
        part gearSensor : GearSensor;
        part tempSensor : FluidTempSensor;
        part transmission : TransmissionAssembly;
        
        connect speedSensor.speedOut to tcu.speedIn;
        connect rpmSensor.rpmOut to tcu.rpmIn;
        connect throttleSensor.throttleOut to tcu.throttleIn;
        connect gearSensor.gearOut to tcu.gearIn;
        connect tempSensor.tempOut to tcu.tempIn;
        connect tcu.commandOut to transmission.commandIn;
    }
    
    // --- Requirements ---
    requirement def TCU_ShiftTimeRequirement {
        doc /* The TCU must execute gear shifts in under 0.8 seconds */
    }
    
    requirement tcuShiftTimeReq : TCU_ShiftTimeRequirement {
        subject tcu : TransmissionControlUnit;
        constraint { tcu.lastShiftDuration < 0.8 [s] }
    }
    
    requirement def TCU_OperationalCycleRequirement {
        doc /* System must constantly read, analyze, calculate, execute, and confirm */
    }
    
    requirement tcuOpCycleReq : TCU_OperationalCycleRequirement {
        subject tcu : TransmissionControlUnit;
    }
    
    requirement def TCU_PerformanceRequirement {
        doc /* Manage gear shifting to optimize performance, fuel efficiency, comfort */
        requirement shiftTime : TCU_ShiftTimeRequirement;
        requirement opCycle : TCU_OperationalCycleRequirement;
    }
}
