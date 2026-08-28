package SewingMachineSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ---------- Value Types ----------
    value def Pressure :> Real { unit 'N/m2'; }
    value def Force :> Real { unit 'N'; }
    value def Speed :> Real { unit 'rpm'; }
    value def LinearSpeed :> Real { unit 'mm/s'; }
    value def Distance :> Real { unit 'mm'; }
    value def Angle :> Real { unit 'deg'; }
    value def Tension :> Real { unit 'N'; }
    value def Voltage :> Real { unit 'V'; }
    value def Current :> Real {> Real { unit 'A'; }
    value def Power :> Real { unit 'W'; }
    value def StitchCount :> Integer;
    value def PressurePercent :> Real { unit '%'; }

    // ---------- Items ----------
    item def Fabric;
    item def Thread {
        attribute tensileStrength : Tension;
        attribute lengthRemaining : Distance;
    }
    item def UpperThread :> Thread;
    item def LowerThread :> Thread;
    item def Stitch {
        attribute length : Distance;
        attribute index : StitchCount;
    }
    item def Seam {
        attribute stitches : StitchCount;
        attribute totalLength : Distance;
    }

    // ---------- Port Definitions ----------
    port def PowerPort {
        attribute voltage : Voltage;
        out current : Current;
    }
    port def ControlSignalPort {
        attribute command : String;
        attribute value : Real;
    }
    port def PedalSignalPort {
        attribute pressurePercent : PressurePercent;
    }
    port def MechanicalDrivePort {
        attribute torque : Real;
        attribute speed : Speed;
    }
    port def ThreadPort {
        out thread : Thread;
    }
    port def FabricPort {
        inout fabric : Fabric;
    }

    // ---------- Requirements ----------
    requirement def PowerRequirement {
        subject powerSource : PowerSource;
        attribute requiredVoltage : Voltage = 110 [V];
        constraint { powerSource.voltage == requiredVoltage }
    }

    requirement def SpeedControlRequirement {
        subject pedal : FootPedal;
        subject motor : DriveMotor;
        constraint {
            motor.speed == pedal.appliedPressure.value * 10.0
        }
    }

    requirement def TensionRegulationRequirement {
        subject regulator : TensionRegulator;
        attribute targetTension : Tension = 0.5 [N];
        constraint { regulator.regulatedTension == targetTension }
    }

    requirement def StitchFormationRequirement {
        subject needle : Needle;
        subject bobbin : BobbinAssembly;
        constraint {
            needle.position == bobbin.catchAngle
        }
    }

    requirement def FeedDogRequirement {
        subject feedDog : FeedDog;
        attribute stitchLength : Distance = 2.5 [mm];
        constraint { feedDog.advanceDistance == stitchLength }
    }

    requirement def SeamUniformityRequirement {
        subject machine : SewingMachine;
        constraint {
            machine.seam.totalLength == machine.seam.stitches * 2.5 [mm]
        }
    }

    requirement def SafetyRequirement {
        subject machine : SewingMachine;
        constraint {
            machine.state == 'error' implies machine.motor.speed == 0 [rpm]
        }
    }

    // ---------- Part Definitions ----------

    part def PowerSource {
        port out power : PowerPort;
        attribute voltage : Voltage = 110 [V];
        attribute maxPower : Power = 150 [W];
    }

    part def FootPedal {
        port out signal : PedalSignalPort;
        attribute appliedPressure : Pressure;
        attribute pressurePercent : PressurePercent;
        
        action def ApplyPressure(in amount : Pressure) {
            then UpdateSignal();
        }
        action def UpdateSignal {
            assign pressurePercent : 
                PressurePercent = (appliedPressure / 100.0 [N/m2]) * 100.0 [%];
        }
    }

    part def DriveMotor {
        port in powerIn : PowerPort;
        port in controlIn : ControlSignalPort;
        port out drive : MechanicalDrivePort;
        attribute speed : Speed;
        attribute maxSpeed : Speed = 1200 [rpm];
        attribute running : Boolean = false;
        
        action def StartMotor {
            assign running = true;
        }
        action def StopMotor {
            assign running = false;
            assign speed = 0 [rpm];
        }
        action def SetSpeed(in targetSpeed : Speed) {
            assign speed = targetSpeed;
        }
    }

    part def ControlUnit {
        port in pedalInput : PedalSignalPort;
        port out motorControl : ControlSignalPort;
        port out needleControl : ControlSignalPort;
        port out bobbinControl : ControlSignalPort;
        port out feedDogControl : ControlSignalPort;
        port out presserFootControl : ControlSignalPort;
        
        attribute currentState : String;
        attribute stitchCount : StitchCount = 0;
        attribute targetStitchLength : Distance = 2.5 [mm];
        
        action def InterpretPedal {
            assign motorControl.value = pedalInput.pressurePercent * 12.0;
        }
        
        action def SynchronizeStitchCycle {
            // Sequence the stitch formation steps
            then DriveNeedleDown();
            then RotateBobbin();
            then RetractNeedle();
            then AdvanceFeedDog();
        }
        
        action def DriveNeedleDown {
            assign needleControl.command = 'down';
        }
        action def RotateBobbin {
            assign bobbinControl.command = 'catch';
        }
        action def RetractNeedle {
            assign needleControl.command = 'up';
        }
        action def AdvanceFeedDog {
            assign feedDogControl.command = 'advance';
            assign stitchCount = stitchCount + 1;
        }
        
        state machine ControlStateMachine {
            entry; then idle;
            
            state idle;
            state preparing;
            state threading;
            state positioningFabric;
            state sewing;
            state paused;
            state error;
            
            transition idle to preparing
                when pedalInput.pressurePercent > 0.0 [%];
            transition preparing to threading
                when controlIn.command == 'thread';
            transition threading to positioningFabric
                when needleControl.command == 'threaded';
            transition positioningFabric to sewing
                when presserFootControl.command == 'engaged';
            transition sewing to paused
                when pedalInput.pressurePercent == 0.0 [%];
            transition paused to sewing
                when pedalInput.pressurePercent > 0.0 [%];
            transition sewing to error
                when needleControl.command == 'threadBreak';
            transition error to idle
                when controlIn.command == 'reset';
            transition sewing to idle
                when controlIn.command == 'stop';
        }
    }

    part def MainSpool {
        port out threadSupply : ThreadPort;
        attribute thread : UpperThread;
        attribute capacity : Distance = 100.0 [m];
        attribute remaining : Distance;
    }

    part def TensionRegulator {
        port in threadIn : ThreadPort;
        port out threadOut : ThreadPort;
        attribute regulatedTension : Tension = 0.5 [N];
        attribute tensionRange : Tension = 2.0 [N];
        
        action def RegulateTension {
            // Maintain consistent thread tension
        }
    }

    part def NeedleBar {
        port in control : ControlSignalPort;
        port in threadIn : ThreadPort;
        port out threadOut : ThreadPort;
        attribute position : Distance;
        attribute maxStroke : Distance = 15.0 [mm];
        attribute moving : Boolean = false;
        
        action def DriveDown {
            assign position = maxStroke;
            assign moving = true;
        }
        action def RetractUp {
            assign position = 0.0 [mm];
            assign moving = true;
        }
        action def Stop {
            assign moving = false;
        }
    }

    part def Needle {
        port in threadIn : ThreadPort;
        attribute tipPosition : Distance;
        attribute sharpness : Real;
        attribute threadBreakDetected : Boolean = false;
        
        action def PierceFabric(in fabric : Fabric) {
            // Penetrate fabric layers
        }
        action def CarryThread {
            // Form loop below fabric
        }
        action def DetectThreadBreak {
            assign threadBreakDetected = true;
        }
    }

    part def Bobbin {
        port out threadSupply : ThreadPort;
        attribute thread : LowerThread;
        attribute capacity : Distance = 20.0 [m];
        attribute remaining : Distance;
    }

    part def BobbinAssembly {
        port in control : ControlSignalPort;
        port in bobbinThread : ThreadPort;
        attribute rotationAngle : Angle;
        attribute catchAngle : Angle = 180.0 [deg];
        attribute rotating : Boolean = false;
        
        action def RotateToCatch {
            assign rotating = true;
            assign rotationAngle = catchAngle;
        }
        action def InterlockThreads {
            // Interlock upper thread loop with lower thread
        }
        action def StopRotation {
            assign rotating = false;
        }
    }

    part def PresserFoot {
        port in control : ControlSignalPort;
        port inout fabric : FabricPort;
        attribute appliedForce : Force = 5.0 [N];
        attribute engaged : Boolean = false;
        
        action def Engage {
            assign engaged = true;
        }
        action def Disengage {
            assign engaged = false;
        }
        action def ApplyPressure {
            // Hold fabric firmly
        }
    }

    part def FeedDog {
        port in control : ControlSignalPort;
        port inout fabric : FabricPort;
        attribute advanceDistance : Distance = 2.5 [mm];
        attribute teethEngaged : Boolean = false;
        attribute moving : Boolean = false;
        
        action def AdvanceFabric {
            assign moving = true;
            assign teethEngaged = true;
            // Push material forward by stitch length
        }
        action def Reset {
            assign moving = false;
            assign teethEngaged = false;
        }
    }

    part def FabricBed {
        port inout fabric : FabricPort;
        attribute surfaceArea : Distance;
        attribute stitchPlateOpening : Distance = 7.0 [mm];
    }

    // ---------- Main Sewing Machine ----------
    part def SewingMachine {
        attribute state : String;
        attribute seam : Seam;
        
        port in powerInput : PowerPort;
        port in pedalInput : PedalSignalPort;
        port inout fabricIO : FabricPort;
        
        part powerSource : PowerSource {
            satisfy PowerRequirement;
        }
        
        part footPedal : FootPedal {
            attribute appliedPressure : Pressure;
        }
        
        part motor : DriveMotor {
            satisfy SpeedControlRequirement;
        }
        
        part controlUnit : ControlUnit;
        
        part mainSpool : MainSpool;
        
        part tensionRegulator : TensionRegulator {
            satisfy TensionRegulationRequirement;
        }
        
        part needleBar : NeedleBar;
        
        part needle : Needle {
            satisfy StitchFormationRequirement;
        }
        
        part bobbin : Bobbin;
        
        part bobbinAssembly : BobbinAssembly {
            satisfy StitchFormationRequirement;
        }
        
        part presserFoot : PresserFoot;
        
        part feedDog : FeedDog {
            satisfy FeedDogRequirement;
        }
        
        part fabricBed : FabricBed;
        
        // Connections
        connection powerSource.power to motor.powerIn;
        connection powerSource.power to controlUnit.powerIn;
        connection footPedal.signal to controlUnit.pedalInput;
        connection controlUnit.motorControl to motor.controlIn;
        connection controlUnit.needleControl to needleBar.control;
        connection controlUnit.bobbinControl to bobbinAssembly.control;
        connection controlUnit.feedDogControl to feedDog.control;
        connection controlUnit.presserFootControl to presserFoot.control;
        
        connection mainSpool.threadSupply to tensionRegulator.threadIn;
        connection tensionRegulator.threadOut to needleBar.threadIn;
        connection needleBar.threadOut to needle.threadIn;
        
        connection bobbin.threadSupply to bobbinAssembly.bobbinThread;
        
        connection fabricIO to presserFoot.fabric;
        connection presserFoot.fabric to feedDog.fabric;
        connection feedDog.fabric to fabricBed.fabric;
        
        // Main operational behavior
        action def StitchCycle {
            // Step 1: Needle drives down piercing fabric
            action needleDown {
                assign needleBar.position = needleBar.maxStroke;
                assign needle.tipPosition = needleBar.maxStroke;
            }
            // Step 2: Bobbin rotates to catch upper thread loop
            action bobbinCatch {
                assign bobbinAssembly.rotationAngle = bobbinAssembly.catchAngle;
            }
            // Step 3: Needle retracts upward
            action needleUp {
                assign needleBar.position = 0.0 [mm];
                assign needle.tipPosition = 0.0 [mm];
            }
            // Step 4: Feed dog advances fabric
            action feedAdvance {
                assign feedDog.advanceDistance = controlUnit.targetStitchLength;
                assign seam.stitches = seam.stitches + 1;
                assign seam.totalLength = seam.totalLength + feedDog.advanceDistance;
            }
            
            flow needleDown to bobbinCatch;
            flow bobbinCatch to needleUp;
            flow needleUp to feedAdvance;
        }
        
        action def SewingOperation {
            loop {
                StitchCycle();
            }
        }
        
        state machine MachineStateMachine {
            entry; then idle;
            
            state idle {
                entry assign state = 'idle';
                assign motor.speed = 0 [rpm];
            }
            
            state preparing {
                entry assign state = 'preparing';
            }
            
            state threading {
                entry assign state = 'threading';
                // Thread upper path: spool -> tension -> needle
                // Thread lower path: bobbin -> bobbin assembly
            }
            
            state positioningFabric {
                entry assign state = 'positioning';
                assign presserFoot.engaged = true;
            }
            
            state sewing {
                entry assign state = 'sewing';
                do SewingOperation();
            }
            
            state paused {
                entry assign state = 'paused';
                assign motor.speed = 0 [rpm];
            }
            
            state error {
                entry assign state = 'error';
                assign motor.speed = 0 [rpm];
                assign motor.running = false;
            }
            
            transition idle to preparing
                when pedalInput.pressurePercent > 0.0 [%];
            transition preparing to threading
                when controlUnit.needleControl.command == 'thread';
            transition threading to positioningFabric
                when needle.threadIn.thread.lengthRemaining > 0.0 [mm];
            transition positioningFabric to sewing
                when presserFoot.engaged == true;
            transition sewing to paused
                when pedalInput.pressurePercent == 0.0 [%];
            transition paused to sewing
                when pedalInput.pressurePercent > 0.0 [%];
            transition sewing to error
                when needle.threadBreakDetected == true;
            transition error to idle
                when controlUnit.controlIn.command == 'reset';
            transition sewing to idle
                when controlUnit.controlIn.command == 'stop';
        }
        
        satisfy SeamUniformityRequirement;
        satisfy SafetyRequirement;
    }

}
