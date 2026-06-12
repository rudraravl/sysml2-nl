package ElectricUnicycleSystemModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    item def RiderMass;
    item def TorqueCommand;
    item def SpeedCommand;
    item def BalanceEstimate;
    item def PowerFlow;
    item def DiagnosticMessage;
    item def UserAlert;
    item def RideTelemetry;

    value def Voltage :> ISQ::electricPotential {
        unit = "V";
    }

    value def Current :> ISQ::electricCurrent {
        unit = "A";
    }

    value def Power :> ISQ::power {
        unit = "W";
    }

    value def Energy :> ISQ::energy {
        unit = "Wh";
    }

    value def Torque :> ISQ::torque {
        unit = "N*m";
    }

    value def AngularVelocity :> ISQ::angularVelocity {
        unit = "rad/s";
    }

    value def LinearSpeed :> ISQ::speed {
        unit = "km/h";
    }

    value def Acceleration :> ISQ::acceleration {
        unit = "m/s^2";
    }

    value def Angle :> ISQ::planeAngle {
        unit = "deg";
    }

    value def Temperature :> ISQ::thermodynamicTemperature {
        unit = "degC";
    }

    value def Distance :> ISQ::length {
        unit = "km";
    }

    value def Mass :> ISQ::mass {
        unit = "kg";
    }

    enum def RideMode {
        enum Eco;
        enum Normal;
        enum Sport;
        enum WalkAssist;
        enum FaultLimited;
    }

    enum def SystemHealth {
        enum Nominal;
        enum Warning;
        enum Critical;
        enum ShutdownRequired;
    }

    port def MechanicalDrivePort {
        out driveTorque : TorqueCommand;
        in wheelSpeed : AngularVelocity;
    }

    port def ElectricalPowerPort {
        in voltage : Voltage;
        in currentLimit : Current;
        out currentDraw : Current;
        out powerDemand : PowerFlow;
    }

    port def SensorDataPort {
        out pitchAngle : Angle;
        out rollAngle : Angle;
        out yawRate : AngularVelocity;
        out longitudinalAcceleration : Acceleration;
        out lateralAcceleration : Acceleration;
        out wheelAngularVelocity : AngularVelocity;
        out boardTemperature : Temperature;
    }

    port def ControlCommandPort {
        in riderLeanAngle : Angle;
        in measuredSpeed : LinearSpeed;
        in balance : BalanceEstimate;
        out motorTorqueCommand : TorqueCommand;
        out activeMode : RideMode;
    }

    port def UserInterfacePort {
        in telemetry : RideTelemetry;
        in alert : UserAlert;
        out powerButtonPressed : Boolean;
        out rideModeRequest : RideMode;
    }

    part def BatteryPack {
        attribute nominalVoltage : Voltage = 100.8 [V];
        attribute maximumVoltage : Voltage = 126.0 [V];
        attribute minimumSafeVoltage : Voltage = 84.0 [V];
        attribute capacity : Energy = 2220 [Wh];
        attribute maximumDischargeCurrent : Current = 180 [A];
        attribute stateOfCharge : Real;
        attribute packTemperature : Temperature;
        attribute health : SystemHealth;

        port dcOutput : ElectricalPowerPort;

        action balanceCells {
            in cellVoltageSpread : Voltage;
            out balanced : Boolean;
        }

        action providePower {
            in requestedPower : Power;
            out availablePower : Power;
            out currentLimit : Current;
        }

        state def BatteryProtection {
            entry action initializeBatteryMonitoring;
            state Ready;
            state LowChargeWarning;
            state OverTemperatureLimited;
            state Cutoff;

            transition first Ready;
            transition Ready to LowChargeWarning
                if stateOfCharge <= 0.15;
            transition LowChargeWarning to Ready
                if stateOfCharge > 0.20;
            transition Ready to OverTemperatureLimited
                if packTemperature >= 55 [degC];
            transition OverTemperatureLimited to Ready
                if packTemperature <= 45 [degC];
            transition LowChargeWarning to Cutoff
                if stateOfCharge <= 0.03;
            transition OverTemperatureLimited to Cutoff
                if packTemperature >= 70 [degC];
        }
    }

    part def MotorController {
        attribute maximumPhaseCurrent : Current = 300 [A];
        attribute switchingFrequency : Real = 20000;
        attribute controllerTemperature : Temperature;
        attribute torqueLimit : Torque = 220 [N*m];
        attribute regenerativeBrakingLimit : Power = 2500 [W];

        port powerInput : ElectricalPowerPort;
        port driveOutput : MechanicalDrivePort;
        port commandInput : ControlCommandPort;

        action convertDcToPhasePower {
            in dcVoltage : Voltage;
            in torqueRequest : Torque;
            out phaseCurrent : Current;
            out deliveredTorque : Torque;
        }

        action applyRegenerativeBraking {
            in brakingTorque : Torque;
            out returnedPower : Power;
        }

        state def ControllerOperation {
            state Disabled;
            state TorqueControl;
            state RegenerativeBraking;
            state ThermalDerate;
            state FaultOff;

            transition first Disabled;
            transition Disabled to TorqueControl
                if commandInput.activeMode != RideMode::WalkAssist;
            transition TorqueControl to RegenerativeBraking
                if commandInput.motorTorqueCommand < 0 [N*m];
            transition RegenerativeBraking to TorqueControl
                if commandInput.motorTorqueCommand >= 0 [N*m];
            transition TorqueControl to ThermalDerate
                if controllerTemperature >= 85 [degC];
            transition ThermalDerate to TorqueControl
                if controllerTemperature <= 75 [degC];
            transition ThermalDerate to FaultOff
                if controllerTemperature >= 105 [degC];
        }
    }

    part def HubMotorWheel {
        attribute wheelDiameter : ISQ::length = 0.508 [m];
        attribute tirePressure : Real = 2.8;
        attribute peakTorque : Torque = 220 [N*m];
        attribute continuousTorque : Torque = 95 [N*m];
        attribute maximumWheelSpeed : AngularVelocity = 95 [rad/s];
        attribute vehicleSpeed : LinearSpeed;
        attribute wheelSpeed : AngularVelocity;

        port driveInput : MechanicalDrivePort;

        action generateGroundForce {
            in appliedTorque : Torque;
            in riderMass : Mass;
            out forwardAcceleration : Acceleration;
        }

        action absorbRoadDisturbance {
            in obstacleHeight : ISQ::length;
            out pitchDisturbance : Angle;
        }
    }

    part def InertialMeasurementUnit {
        attribute pitchAccuracy : Angle = 0.2 [deg];
        attribute gyroRange : AngularVelocity = 34.9 [rad/s];
        attribute sampleRate : Real = 1000;
        attribute measuredPitch : Angle;
        attribute measuredRoll : Angle;

        port sensorOutput : SensorDataPort;

        action estimateAttitude {
            in gyroRate : AngularVelocity;
            in acceleration : Acceleration;
            out pitch : Angle;
            out roll : Angle;
        }
    }

    part def BalanceController {
        attribute targetPitch : Angle = 0 [deg];
        attribute maximumSafePitch : Angle = 18 [deg];
        attribute maximumSpeed : LinearSpeed = 55 [km/h];
        attribute tiltBackSpeed : LinearSpeed = 50 [km/h];
        attribute controlLoopRate : Real = 1000;
        attribute rideMode : RideMode = RideMode::Normal;
        attribute systemHealth : SystemHealth = SystemHealth::Nominal;

        port sensorInput : SensorDataPort;
        port commandOutput : ControlCommandPort;
        port userInput : UserInterfacePort;

        action computeBalanceEstimate {
            in pitch : Angle;
            in pitchRate : AngularVelocity;
            in acceleration : Acceleration;
            out balance : BalanceEstimate;
        }

        action computeTorqueCommand {
            in balance : BalanceEstimate;
            in riderLean : Angle;
            in speed : LinearSpeed;
            out command : TorqueCommand;
        }

        action enforceSpeedEnvelope {
            in measuredSpeed : LinearSpeed;
            in requestedTorque : TorqueCommand;
            out limitedTorque : TorqueCommand;
            out alert : UserAlert;
        }

        state def RideControlStateMachine {
            state Off;
            state SelfTest;
            state Standby;
            state MountAssist;
            state Balancing;
            state TiltBack;
            state FaultLimited;
            state EmergencyShutdown;

            transition first Off;
            transition Off to SelfTest
                accept userInput.powerButtonPressed;
            transition SelfTest to Standby
                if systemHealth == SystemHealth::Nominal;
            transition SelfTest to FaultLimited
                if systemHealth == SystemHealth::Warning;
            transition Standby to MountAssist
                if abs(sensorInput.pitchAngle) < 5 [deg];
            transition MountAssist to Balancing
                if abs(sensorInput.pitchAngle) < 2 [deg];
            transition Balancing to TiltBack
                if commandOutput.measuredSpeed >= tiltBackSpeed;
            transition TiltBack to Balancing
                if commandOutput.measuredSpeed < 0.9 * tiltBackSpeed;
            transition Balancing to FaultLimited
                if systemHealth == SystemHealth::Warning;
            transition FaultLimited to EmergencyShutdown
                if systemHealth == SystemHealth::Critical or systemHealth == SystemHealth::ShutdownRequired;
            transition Balancing to EmergencyShutdown
                if abs(sensorInput.pitchAngle) >= maximumSafePitch;
        }
    }

    part def RiderInterface {
        attribute speakerVolume : Real = 0.8;
        attribute displayBrightness : Real = 0.7;
        attribute hapticEnabled : Boolean = true;

        port uiPort : UserInterfacePort;

        action displayTelemetry {
            in speed : LinearSpeed;
            in batteryStateOfCharge : Real;
            in remainingRange : Distance;
        }

        action issueWarning {
            in alert : UserAlert;
            out audible : Boolean;
            out visual : Boolean;
            out haptic : Boolean;
        }
    }

    part def StructuralFrame {
        attribute frameMass : Mass = 11.5 [kg];
        attribute maximumRiderMass : Mass = 120 [kg];
        attribute ingressProtectionRating : String = "IPX6";
        attribute footPlatformHeight : ISQ::length = 0.17 [m];

        part leftPedal;
        part rightPedal;
        part batteryEnclosure;
        part motorMount;
        part handle;
    }

    part def ThermalManagement {
        attribute controllerHeatSinkTemperature : Temperature;
        attribute motorTemperature : Temperature;
        attribute batteryTemperature : Temperature;
        attribute derateTemperature : Temperature = 80 [degC];
        attribute shutdownTemperature : Temperature = 105 [degC];

        action evaluateThermalLimits {
            in controllerTemperature : Temperature;
            in motorTemperature : Temperature;
            in batteryTemperature : Temperature;
            out health : SystemHealth;
            out torqueDerateFactor : Real;
        }
    }

    part def Diagnostics {
        attribute lastFaultCode : String;
        attribute serviceRequired : Boolean;
        attribute insulationResistanceOk : Boolean;

        action runPowerOnSelfTest {
            out batteryOk : Boolean;
            out controllerOk : Boolean;
            out imuOk : Boolean;
            out motorOk : Boolean;
            out health : SystemHealth;
        }

        action recordFault {
            in message : DiagnosticMessage;
            out stored : Boolean;
        }
    }

    part def ElectricUnicycle {
        attribute curbMass : Mass = 32 [kg];
        attribute ratedRiderMass : Mass = 100 [kg];
        attribute maximumRiderMass : Mass = 120 [kg];
        attribute maximumSpeed : LinearSpeed = 55 [km/h];
        attribute practicalRange : Distance = 95 [km];
        attribute nominalSystemVoltage : Voltage = 100.8 [V];

        part battery : BatteryPack;
        part controller : MotorController;
        part motorWheel : HubMotorWheel;
        part imu : InertialMeasurementUnit;
        part balanceController : BalanceController;
        part riderInterface : RiderInterface;
        part frame : StructuralFrame;
        part thermalManagement : ThermalManagement;
        part diagnostics : Diagnostics;

        port riderUi : UserInterfacePort;
        port externalChargePort : ElectricalPowerPort;

        connect battery.dcOutput to controller.powerInput;
        connect controller.driveOutput to motorWheel.driveInput;
        connect imu.sensorOutput to balanceController.sensorInput;
        connect balanceController.commandOutput to controller.commandInput;
        connect riderInterface.uiPort to balanceController.userInput;
        connect riderUi to riderInterface.uiPort;
        connect externalChargePort to battery.dcOutput;

        action primaryFunction {
            in riderLean : Angle;
            in riderMass : Mass;
            out forwardMotion : LinearSpeed;
            out stabilizedPitch : Angle;
            out userTelemetry : RideTelemetry;

            first startBalanceLoop;
            then senseRiderLean;
            then estimateVehicleAttitude;
            then computeMotorTorque;
            then deliverTorqueToHubWheel;
            then stabilizeSingleWheelMotion;
            then reportRideTelemetry;
        }

        action startBalanceLoop;
        action senseRiderLean;
        action estimateVehicleAttitude;
        action computeMotorTorque;
        action deliverTorqueToHubWheel;
        action stabilizeSingleWheelMotion;
        action reportRideTelemetry;
    }

    requirement def PrimaryFunctionRequirement {
        subject unicycle : ElectricUnicycle;

        require constraint {
            unicycle shall transport a standing rider on one wheel by continuously sensing body lean and wheel motion, computing corrective torque, and driving the hub motor to maintain balance while producing commanded forward or reverse motion.
        }
    }

    requirement def BalanceStabilityRequirement {
        subject unicycle : ElectricUnicycle;

        require constraint {
            abs(unicycle.imu.measuredPitch) <= 5 [deg] during normal balancing operation when rider mass <= unicycle.maximumRiderMass and speed <= unicycle.maximumSpeed.
        }
    }

    requirement def SpeedLimitRequirement {
        subject unicycle : ElectricUnicycle;

        require constraint {
            unicycle.balanceController.commandOutput.measuredSpeed <= unicycle.maximumSpeed;
        }
    }

    requirement def BatteryEnergyRequirement {
        subject unicycle : ElectricUnicycle;

        require constraint {
            unicycle.battery.capacity >= 2000 [Wh];
        }
    }

    requirement def RiderMassRequirement {
        subject unicycle : ElectricUnicycle;

        require constraint {
            unicycle.frame.maximumRiderMass >= 120 [kg];
        }
    }

    requirement def ThermalProtectionRequirement {
        subject unicycle : ElectricUnicycle;

        require constraint {
            unicycle.thermalManagement.shutdownTemperature <= 105 [degC];
        }
    }

    requirement def UserWarningRequirement {
        subject unicycle : ElectricUnicycle;

        require constraint {
            unicycle.riderInterface shall issue audible, visual, or haptic alerts before speed tilt-back, low battery cutoff, thermal derating, and critical shutdown.
        }
    }

    requirement def RegenerativeBrakingRequirement {
        subject unicycle : ElectricUnicycle;

        require constraint {
            unicycle.controller.regenerativeBrakingLimit >= 2000 [W];
        }
    }

    satisfy PrimaryFunctionRequirement by ElectricUnicycle::primaryFunction;
    satisfy BalanceStabilityRequirement by ElectricUnicycle::balanceController;
    satisfy SpeedLimitRequirement by ElectricUnicycle::balanceController::enforceSpeedEnvelope;
    satisfy BatteryEnergyRequirement by ElectricUnicycle::battery;
    satisfy RiderMassRequirement by ElectricUnicycle::frame;
    satisfy ThermalProtectionRequirement by ElectricUnicycle::thermalManagement;
    satisfy UserWarningRequirement by ElectricUnicycle::riderInterface;
    satisfy RegenerativeBrakingRequirement by ElectricUnicycle::controller;

    part electricUnicycleSystem : ElectricUnicycle {
        attribute curbMass = 32 [kg];
        attribute ratedRiderMass = 100 [kg];
        attribute maximumSpeed = 55 [km/h];
        attribute practicalRange = 95 [km];
    }
}