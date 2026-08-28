package PersonalTransporter {

    import SI::*;
    import ScalarValues::*;

    // ---------------- Value Types ----------------
    value type TorqueValue :> Real {
        unit 'N·m';
    }
    value type AngleValue :> Real {
        unit 'rad';
    }
    value type AngularRateValue :> Real {
        unit 'rad/s';
    }
    value type LinearVelocityValue :> Real {
        unit 'm/s';
    }
    value type VoltageValue :> Real {
        unit 'V';
    }
    value type CurrentValue :> Real {
        unit 'A';
    }
    value type PowerValue :> Real {
        unit 'W';
    }
    value type MassValue :> Real {
        unit 'kg';
    }
    value type LengthValue :> Real {
        unit 'm';
    }
    value type TimeValue :> Real {
        unit 's';
    }
    value type ForceValue :> Real {
        unit 'N';
    }

    // ---------------- Enumerations ----------------
    enum OperationalStateKind {
        powerOff;
        initializing;
        standby;
        balancing;
        moving;
        fault;
    }

    enum DirectionKind {
        forward;
        reverse;
        stopped;
    }

    enum FaultKind {
        none;
        lowBattery;
        sensorFailure;
        motorFault;
        controllerFault;
        tiltExceeded;
    }

    // ---------------- Item Definitions ----------------
    item def TiltData {
        attribute angle : AngleValue;
        attribute rate : AngularRateValue;
    }

    item def RiderCommand {
        attribute leanAngle : AngleValue;
        attribute leanRate : AngularRateValue;
        attribute steerIntent : Real; // -1..+1, negative = left, positive = right
        attribute direction : DirectionKind;
    }

    item def MotorCommand {
        attribute leftTorque : TorqueValue;
        attribute rightTorque : TorqueValue;
    }

    item def PowerFlow {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }

    item def FaultSignal {
        attribute fault : FaultKind;
    }

    // ---------------- Port Definitions ----------------
    port def TiltDataOut {
        out data : TiltData;
    }
    port def TiltDataIn {
        in data : TiltData;
    }
    port def RiderCommandOut {
        out cmd : RiderCommand;
    }
    port def RiderCommandIn {
        in cmd : RiderCommand;
    }
    port def MotorCommandOut {
        out cmd : MotorCommand;
    }
    port def MotorCommandIn {
        in cmd : MotorCommand;
    }
    port def PowerOut {
        out p : PowerFlow;
    }
    port def PowerIn {
        in p : PowerFlow;
    }
    port def FaultOut {
        out f : FaultSignal;
    }
    port def FaultIn {
        in f : FaultSignal;
    }

    // ---------------- Requirements ----------------
    requirement def BalanceRequirement {
        doc /* The transporter shall keep its platform level within ±0.5° of upright while balancing. */
        attribute maxTiltAngle : AngleValue = 0.5 [rad] / 8.0; // approx 3.6°; tighter spec used
        requirement { subject platformTiltAngle : AngleValue;
            platformTiltAngle <= 0.1 [rad];
        }
    }

    requirement def RiderCarryRequirement {
        attribute maxRiderMass : MassValue = 120 [kg];
        attribute minRiderMass : MassValue = 20 [kg];
    }

    requirement def MotorTorqueRequirement {
        attribute peakTorque : TorqueValue = 60 [N·m];
    }

    requirement def BatteryRequirement {
        attribute minVoltage : VoltageValue = 36 [V];
        attribute maxCurrent : CurrentValue = 60 [A];
        attribute minCapacity : CurrentValue = 10 [A];
    }

    requirement def OperationalStateRequirement {
        doc /* The transporter shall implement powerOff, initializing, standby, balancing, moving, and fault states. */
    }

    requirement def TransporterRequirement {
        satisfy BalanceRequirement;
        satisfy RiderCarryRequirement;
        satisfy MotorTorqueRequirement;
        satisfy BatteryRequirement;
        satisfy OperationalStateRequirement;
    }

    // ---------------- Part Definitions ----------------
    part def Gyroscope {
        port tiltOut : TiltDataOut;
        attribute sampleRate : TimeValue = 0.01 [s];
        action def update() {
            // produce angular rate measurement
        }
    }

    part def Accelerometer {
        port tiltOut : TiltDataOut;
        attribute sampleRate : TimeValue = 0.01 [s];
        action def update() {
            // produce tilt angle measurement
        }
    }

    part def LeanSensor {
        port commandOut : RiderCommandOut;
        attribute detectedLean : AngleValue = 0 [rad];
        action def detectRiderLean() {
            // detect forward/backward lean and steer intent
        }
    }

    part def BalanceController {
        port tiltIn1 : TiltDataIn;
        port tiltIn2 : TiltDataIn;
        port commandIn : RiderCommandIn;
        port leftMotorCmdOut : MotorCommandOut;
        port rightMotorCmdOut : MotorCommandOut;
        port powerIn : PowerIn;
        port faultOut : FaultOut;

        attribute kp : Real = 25.0;
        attribute kd : 1.5;
        attribute kLean : Real = 8.0;
        attribute kSteer : Real = 5.0;
        attribute maxTorque : TorqueValue = 60 [N·m];
        attribute currentTilt : AngleValue;
        attribute currentRate : AngularRateValue;

        action def balanceLoop(in tilt : TiltData, in cmd : RiderCommand, out motorCmd : MotorCommand) {
            // Compute balance torque and propulsion torque
            // motorCmd = (balance + propulsion) for each wheel
            // differential torque used for steering
        }

        action def computeTorques(in tilt : TiltData, in lean : RiderCommand, out cmd : MotorCommand) {
            // PD control on tilt + proportional on lean + differential for steer
        }

        action def runSelfTest(out pass : Boolean) {
            // verify sensors, motors, battery
        }
    }

    part def WheelMotor {
        port commandIn : MotorCommandIn;
        port powerIn : PowerIn;
        port faultOut : FaultOut;
        attribute appliedTorque : TorqueValue = 0 [N·m];
        attribute peakTorque : TorqueValue = 60 [N·m];
        attribute nominalVoltage : VoltageValue = 36 [V];
        action def applyTorque(in cmd : MotorCommand) {
            // drive motor according to command
        }
        action def selfTest(out ok : Boolean) {}
    }

    part def Wheel {
        part motor : WheelMotor;
        attribute radius : LengthValue = 0.2 [m];
        attribute mass : MassValue = 2.5 [kg];
        port mechanicalIf;
    }

    part def BatteryPack {
        port powerOut : PowerOut;
        attribute nominalVoltage : VoltageValue = 36 [V];
        attribute maxCurrent : CurrentValue = 60 [A];
        attribute capacity : CurrentValue = 10 [A];
        attribute stateOfCharge : Real = 1.0;
        action def discharge(out p : PowerFlow) {}
        action def charge() {}
        action def monitorSoC(out low : Boolean) {}
    }

    part def PlatformFrame {
        attribute maxLoad : MassValue = 120 [kg];
        attribute mass : MassValue = 5 [kg];
        attribute length : LengthValue = 0.5 [m];
        attribute width : LengthValue = 0.4 [m];
        port mechanicalAttachment;
    }

    part def HandlebarAssembly {
        part leanSensor : LeanSensor;
        attribute height : LengthValue = 1.0 [m];
        attribute mass : MassValue = 3 [kg];
        port commandOut : RiderCommandOut redefines leanSensor.commandOut;
    }

    part def PersonalTransporter {
        satisfy TransporterRequirement;

        part frame : PlatformFrame;
        part leftWheel : Wheel;
        part rightWheel : Wheel;
        part handlebar : HandlebarAssembly;
        part gyroscope : Gyroscope;
        part accelerometer : Accelerometer;
        part controller : BalanceController;
        part battery : BatteryPack;

        attribute operationalState : OperationalStateKind = OperationalStateKind::powerOff;
        attribute currentFault : FaultKind = FaultKind::none;

        // Connections
        connect gyroscope.tiltOut to controller.tiltIn1;
        connect accelerometer.tiltOut to controller.tiltIn2;
        connect handlebar.commandOut to controller.commandIn;
        connect controller.leftMotorCmdOut to leftWheel.motor.commandIn;
        connect controller.rightMotorCmdOut to rightWheel.motor.commandIn;
        connect battery.powerOut to controller.powerIn;
        connect battery.powerOut to leftWheel.motor.powerIn;
        connect battery.powerOut to rightWheel.motor.powerIn;
        connect controller.faultOut to self.faultHandler;
        connect leftWheel.motor.faultOut to self.motorFaultAggregator;
        connect rightWheel.motor.faultOut to self.motorFaultAggregator;

        // Power distribution
        flow from battery.powerOut.p to controller.powerIn.p;
        flow from battery.powerOut.p to leftWheel.motor.powerIn.p;
        flow from battery.powerOut.p to rightWheel.motor.powerIn.p;

        // State machine
        state operationalStateMachine {
            state powerOffState {
                entry action { operationalState = OperationalStateKind::powerOff; }
            }
            state initializingState {
                entry action { operationalState = OperationalStateKind::initializing; }
                do action { controller.runSelfTest(); }
            }
            state standbyState {
                entry action { operationalState = OperationalStateKind::standby; }
            }
            state balancingState {
                entry action { operationalState = OperationalStateKind::balancing; }
                do action {
                    controller.balanceLoop(
                        tilt = TiltData(angle => gyroscope.tiltOut.data.angle, rate => gyroscope.tiltOut.data.rate),
                        cmd => handlebar.commandOut.cmd
                    );
                }
            }
            state movingState {
                entry action { operationalState = OperationalStateKind::moving; }
                do action {
                    controller.balanceLoop(
                        tilt = TiltData(angle => gyroscope.tiltOut.data.angle, rate => gyroscope.tiltOut.data.rate),
                        cmd => handlebar.commandOut.cmd
                    );
                }
            }
            state faultState {
                entry action { operationalState = OperationalStateKind::fault; }
                do action {
                    // Safe shutdown: cut motor torque, alert user
                    controller.faultOut.f = FaultSignal(fault => currentFault);
                }
            }

            transition powerOn from powerOffState to initializingState
                when self.powerSwitchOn();
            transition initSuccess from initializingState to standbyState
                when self.selfTestPassed();
            transition initFailure from initializingState to faultState
                when self.selfTestFailed();
            transition riderMounts from standbyState to balancingState
                when self.riderDetectedOnPlatform();
            transition riderDismounts from balancingState to standbyState
                when self.riderRemovedFromPlatform();
            transition leanDetected from balancingState to movingState
                when self.riderLeanDetected();
            transition leanStopped from movingState to balancingState
                when self.riderLeanReleased();
            transition criticalFault from balancingState to faultState
                when self.criticalFaultDetected();
            transition criticalFault2 from movingState to faultState
                when self.criticalFaultDetected();
            transition criticalFault3 from standbyState to faultState
                when self.criticalFaultDetected();
            transition reset from faultState to powerOffState
                when self.powerSwitchOff();
            transition powerOff2 from standbyState to powerOffState
                when self.powerSwitchOff();
        }

        action def powerSwitchOn() : Boolean { return true; }
        action def powerSwitchOff() : Boolean { return true; }
        action def selfTestPassed() : Boolean { return currentFault == FaultKind::none; }
        action def selfTestFailed() : Boolean { return currentFault != FaultKind::none; }
        action def riderDetectedOnPlatform() : Boolean { return true; }
        action def riderRemovedFromPlatform() : Boolean { return true; }
        action def riderLeanDetected() : Boolean {
            return handlebar.commandOut.cmd.leanAngle > 0.05 [rad];
        }
        action def riderLeanReleased() : Boolean {
            return handlebar.commandOut.cmd.leanAngle <= 0.05 [rad];
        }
        action def criticalFaultDetected() : Boolean {
            return currentFault != FaultKind::none;
        }
        action def faultHandler(in f : FaultSignal) {
            currentFault = f.fault;
        }
        action def motorFaultAggregator(in f : FaultSignal) {
            currentFault = f.fault;
        }
    }
}
