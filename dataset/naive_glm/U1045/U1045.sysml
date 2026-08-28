package SelfBalancingEUC {
    public import ISQ::*;
    public import ScalarValues::*;

    // ---- Value Types with Units ----
    value type AngleDeg :> Real { unit "deg"; }
    value type AngularRateDegPerSec :> Real { unit "deg/s"; }
    value type TorqueNm :> Real { unit "N·m"; }
    value type VoltageV :> Real { unit "V"; }
    value type CurrentA :> Real { unit "A"; }
    value type PowerW :> Real { unit "W"; }
    value type EnergyWh :> Real { unit "W·h"; }
    value type MassKg :> Real { unit "kg"; }
    value type SpeedKmh :> Real { unit "km/h"; }
    value type PressureN :> Real { unit "N"; }
    value type BatteryPercent :> Real { unit "%"; }
    value type TemperatureC :> Real { unit "°C"; }
    value type LengthM :> Real { unit "m"; }
    value type TimeS :> Real { unit "s"; }

    // ---- Enumerations ----
    enum def OperatingMode { eco; comfort; sport; }
    enum def SystemStatus { normal; warning; fault; }
    enum def RideDirection { forward; brake; idle; reverse; }

    // ---- Item Definitions ----
    item def OrientationData {
        attribute pitch : AngleDeg;
        attribute roll : AngleDeg;
        attribute pitchRate : AngularRateDegPerSec;
        attribute rollRate : AngularRateDegPerSec;
        attribute timestamp : TimeS;
    }

    item def PedalPressureData {
        attribute leftPressure : PressureN;
        attribute rightPressure : PressureN;
        attribute riderDetected : Boolean;
        attribute leanAngle : AngleDeg;
        attribute timestamp : TimeS;
    }

    item def MotorCommand {
        attribute targetTorque : TorqueNm;
        attribute direction : RideDirection;
    }

    item def DisplayInfo {
        attribute mode : OperatingMode;
        attribute batteryLevel : BatteryPercent;
        attribute status : SystemStatus;
        attribute speed : SpeedKmh;
        attribute temperature : TemperatureC;
    }

    item def ElectricalPower {
        attribute voltage : VoltageV;
        attribute current : CurrentA;
    }

    item def FaultEvent {
        attribute code : Integer;
        attribute description : String;
        attribute severity : Integer;
    }

    // ---- Port Definitions ----
    port def OrientationPort {
        out orientation : OrientationData;
    }

    port def PedalDataPort {
        out pedalData : PedalPressureData;
    }

    port def MotorCmdPort {
        in cmd : MotorCommand;
    }

    port def PowerOutPort {
        out power : ElectricalPower;
    }

    port def PowerInPort {
        in power : ElectricalPower;
    }

    port def DisplayPort {
        in info : DisplayInfo;
    }

    port def ChargerPort {
        in chargePower : ElectricalPower;
    }

    // ---- Part Definitions ----

    part def IMU {
        attribute sampleRateHz : Real = 1000;
        attribute pitchRange : AngleDeg = 90;
        attribute rollRange : AngleDeg = 90;
        port orientationOut : OrientationPort;

        attribute currentPitch : AngleDeg = 0;
        attribute currentRoll : AngleDeg = 0;
        attribute currentPitchRate : AngularRateDegPerSec = 0;
        attribute currentRollRate : AngularRateDegPerSec = 0;

        action def SenseOrientation {
            in sampleInterval : TimeS;
            out orientation : OrientationData;
        }

        perform action sense : SenseOrientation {
            in sampleInterval = 0.001;
        }
    }

    part def PedalAssembly {
        attribute maxLoad : MassKg = 120;
        attribute pedalArea : LengthM = 0.25;
        attribute detectionThreshold : PressureN = 30;
        port pedalDataOut : PedalDataPort;

        attribute leftPressure : PressureN = 0;
        attribute rightPressure : PressureN = 0;
        attribute riderDetected : Boolean = false;

        action def DetectRider {
            out data : PedalPressureData;
        }

        action def ComputeLean {
            in left : PressureN;
            in right : PressureN;
            out lean : AngleDeg;
        }

        perform action detect : DetectRider;
        perform action computeLean : ComputeLean;
    }

    part def ElectricMotor {
        attribute maxTorque : TorqueNm = 80;
        attribute maxSpeed : SpeedKmh = 50;
        attribute nominalPower : PowerW = 2000;
        attribute efficiency : Real = 0.85;
        port cmdIn : MotorCmdPort;
        port powerIn : PowerInPort;

        attribute currentTorque : TorqueNm = 0;
        attribute currentSpeed : SpeedKmh = 0;
        attribute temperature : TemperatureC = 25;

        action def ApplyTorque {
            in cmd : MotorCommand;
            in power : ElectricalPower;
        }

        perform action drive : ApplyTorque;
    }

    part def Wheel {
        attribute diameter : LengthM = 0.357;
        attribute tireWidth : LengthM = 0.075;
        attribute maxInflationPressure : PressureN = 350000;
        part motor : ElectricMotor;

        action def Rotate {
            in torque : TorqueNm;
            out speed : SpeedKmh;
        }

        perform action rotate : Rotate;
    }

    part def BatteryPack {
        attribute capacity : EnergyWh = 1554;
        attribute nominalVoltage : VoltageV = 84;
        attribute maxChargeCurrent : CurrentA = 10;
        attribute maxDischargeCurrent : CurrentA = 50;
        attribute chargeLevel : BatteryPercent = 100;
        attribute temperature : TemperatureC = 25;
        port powerOut : PowerOutPort;
        port chargerIn : ChargerPort;

        action def Discharge {
            out power : ElectricalPower;
        }

        action def Charge {
            in chargePower : ElectricalPower;
        }

        action def MonitorCellHealth {
            out fault : FaultEvent;
        }

        perform action supply : Discharge;
        perform action monitor : MonitorCellHealth;
    }

    part def MotorController {
        attribute sampleRateHz : Real = 1000;
        attribute pidKp : Real = 15.0;
        attribute pidKi : Real = 0.5;
        attribute pidKd : Real = 0.8;
        attribute maxOutputTorque : TorqueNm = 80;
        port orientationIn : OrientationPort;
        port pedalIn : PedalDataPort;
        port motorCmdOut : MotorCmdPort;
        port powerIn : PowerInPort;
        port displayOut : DisplayPort;

        attribute mode : OperatingMode = comfort;
        attribute targetTorque : TorqueNm = 0;
        attribute currentDirection : RideDirection = idle;
        attribute faultActive : Boolean = false;

        action def ProcessInputs {
            in orientation : OrientationData;
            in pedalData : PedalPressureData;
            out cmd : MotorCommand;
            out info : DisplayInfo;
        }

        action def ComputeBalanceTorque {
            in pitch : AngleDeg;
            in pitchRate : AngularRateDegPerSec;
            in lean : AngleDeg;
            out torque : TorqueNm;
        }

        action def RunSelfCheck {
            out passed : Boolean;
            out fault : FaultEvent;
        }

        perform action control : ProcessInputs;
        perform action balance : ComputeBalanceTorque;
        perform action selfCheck : RunSelfCheck;
    }

    part def LEDDisplayPanel {
        attribute refreshRateHz : Real = 10;
        port displayIn : DisplayPort;

        attribute mode : OperatingMode = comfort;
        attribute batteryLevel : BatteryPercent = 100;
        attribute status : SystemStatus = normal;
        attribute speed : SpeedKmh = 0;

        action def UpdateDisplay {
            in info : DisplayInfo;
        }

        perform action update : UpdateDisplay;
    }

    part def ChassisFrame {
        attribute maxLoad : MassKg = 120;
        attribute frameMass : MassKg = 3.5;
        attribute material : String = "aluminum alloy";
        attribute impactResistance : PressureN = 5000;
    }

    // ---- Main System ----
    part def SelfBalancingEUC {
        attribute maxSpeed : SpeedKmh = 50;
        attribute maxRange : Real = 80;
        attribute totalMass : MassKg = 14;
        attribute maxRiderMass : MassKg = 120;

        part chassis : ChassisFrame;
        part imu : IMU;
        part pedals : PedalAssembly;
        part wheel : Wheel;
        part controller : MotorController;
        part battery : BatteryPack;
        part display : LEDDisplayPanel;

        connection imu.orientationOut to controller.orientationIn {
            item orientation : OrientationData;
        }

        connection pedals.pedalDataOut to controller.pedalIn {
            item pedalData : PedalPressureData;
        }

        connection controller.motorCmdOut to wheel.motor.cmdIn {
            item cmd : MotorCommand;
        }

        connection battery.powerOut to controller.powerIn {
            item power : ElectricalPower;
        }

        connection battery.powerOut to wheel.motor.powerIn {
            item power : ElectricalPower;
        }

        connection controller.displayOut to display.displayIn {
            item info : DisplayInfo;
        }

        // ---- State Machine ----
        state machine def EUCStateMachine {
            state off;
            state initializing;
            state ready;
            state balancing;
            state riding;
            state charging;
            state fault;

            transition powerOn
                first off then initializing
                when accept PowerOn;

            transition selfCheckPassed
                first initializing then ready
                when accept SelfCheckOK;

            transition selfCheckFailed
                first initializing then fault
                when accept SelfCheckFail;

            transition riderMounted
                first ready then balancing
                when accept RiderDetected;

            transition forwardLean
                first balancing then riding
                when accept ForwardLeanDetected;

            transition leanReduced
                first riding then balancing
                when accept LeanReduced;

            transition riderDismounts
                first balancing then ready
                when accept RiderDismounted;

            transition errorDuringReady
                first ready then fault
                when accept ErrorDetected;

            transition errorDuringBalancing
                first balancing then fault
                when accept ErrorDetected;

            transition errorDuringRiding
                first riding then fault
                when accept ErrorDetected;

            transition chargerConnectedOff
                first off then charging
                when accept ChargerConnected;

            transition chargerConnectedReady
                first ready then charging
                when accept ChargerConnected;

            transition chargingComplete
                first charging then ready
                when accept ChargingComplete;

            transition powerOffFromReady
                first ready then off
                when accept PowerOff;

            transition powerOffFromBalancing
                first balancing then off
                when accept PowerOff;

            transition powerOffFromRiding
                first riding then off
                when accept PowerOff;

            transition powerOffFromCharging
                first charging then off
                when accept PowerOff;

            transition powerOffFromFault
                first fault then off
                when accept PowerOff;
        }

        exhibit state machine behavior : EUCStateMachine;
    }

    // ---- Requirements ----
    requirement def BalanceRequirement {
        subject euc : SelfBalancingEUC;
        objective {
            doc "The EUC shall dynamically maintain pitch balance within ±5 degrees under normal riding conditions by commanding motor torque up to 80 N·m.";
            euc.controller.maxOutputTorque <= 80;
        }
    }

    requirement def RiderDetectionRequirement {
        subject pedals : PedalAssembly;
        objective {
            doc "The pedal assembly shall detect rider presence within 0.5 seconds of mounting when pressure exceeds 30 N.";
            pedals.detectionThreshold <= 30;
        }
    }

    requirement def BatteryRangeRequirement {
        subject battery : BatteryPack;
        objective {
            doc "The battery pack shall provide at least 40 km range in eco mode and 25 km in sport mode.";
            battery.capacity >= 1554;
        }
    }

    requirement def DisplayInfoRequirement {
        subject display : LEDDisplayPanel;
        objective {
            doc "The LED display shall show current operating mode, battery level percentage, and system status at a minimum refresh rate of 5 Hz.";
            display.refreshRateHz >= 5;
        }
    }

    requirement def SafetyFaultRequirement {
        subject euc : SelfBalancingEUC;
        objective {
            doc "The EUC shall transition to the fault state and safely stop the motor when any critical system error is detected.";
        }
    }

    requirement def ChassisStrengthRequirement {
        subject chassis : ChassisFrame;
        objective {
            doc "The chassis frame shall support a rider mass up to 120 kg while remaining under 4 kg itself.";
            chassis.maxLoad >= 120;
            chassis.frameMass <= 4;
        }
    }

    requirement def ForwardMotionRequirement {
        subject euc : SelfBalancingEUC;
        objective {
            doc "When the rider leans forward, the controller shall command forward torque to accelerate the wheel and maintain balance, resulting in forward motion.";
        }
    }

    requirement def BrakingRequirement {
        subject euc : SelfBalancingEUC;
        objective {
            doc "When the rider leans backward, the controller shall command braking torque to decelerate the wheel while maintaining balance.";
        }
    }

    // ---- Requirement Satisfaction ----
    satisfaction BalanceRequirement {
        subject euc : SelfBalancingEUC;
    }

    satisfaction RiderDetectionRequirement {
        subject pedals : PedalAssembly;
    }

    satisfaction BatteryRangeRequirement {
        subject battery : BatteryPack;
    }

    satisfaction DisplayInfoRequirement {
        subject display : LEDDisplayPanel;
    }

    satisfaction SafetyFaultRequirement {
        subject euc : SelfBalancingEUC;
    }

    satisfaction ChassisStrengthRequirement {
        subject chassis : ChassisFrame;
    }
}
