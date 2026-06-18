package ImpellerBasedSystemModel {

    import ScalarValues::*;

    value def Length {
        attribute value : Real;
        attribute unit : String = "m";
    }

    value def Diameter :> Length;

    value def Area {
        attribute value : Real;
        attribute unit : String = "m^2";
    }

    value def VolumeFlowRate {
        attribute value : Real;
        attribute unit : String = "m^3/s";
    }

    value def Pressure {
        attribute value : Real;
        attribute unit : String = "Pa";
    }

    value def PressureRise :> Pressure;

    value def Density {
        attribute value : Real;
        attribute unit : String = "kg/m^3";
    }

    value def DynamicViscosity {
        attribute value : Real;
        attribute unit : String = "Pa*s";
    }

    value def Temperature {
        attribute value : Real;
        attribute unit : String = "degC";
    }

    value def Mass {
        attribute value : Real;
        attribute unit : String = "kg";
    }

    value def RotationalSpeed {
        attribute value : Real;
        attribute unit : String = "rpm";
    }

    value def Torque {
        attribute value : Real;
        attribute unit : String = "N*m";
    }

    value def Power {
        attribute value : Real;
        attribute unit : String = "W";
    }

    value def Voltage {
        attribute value : Real;
        attribute unit : String = "V";
    }

    value def Current {
        attribute value : Real;
        attribute unit : String = "A";
    }

    value def Efficiency {
        attribute value : Real;
        attribute unit : String = "1";
    }

    value def VibrationVelocity {
        attribute value : Real;
        attribute unit : String = "mm/s";
    }

    value def TimeDuration {
        attribute value : Real;
        attribute unit : String = "s";
    }

    value def Angle {
        attribute value : Real;
        attribute unit : String = "deg";
    }

    value def Clearance {
        attribute value : Real;
        attribute unit : String = "mm";
    }

    item def WorkingFluid {
        attribute name : String = "water-compatible process fluid";
        attribute density : Density;
        attribute dynamicViscosity : DynamicViscosity;
        attribute temperature : Temperature;
        attribute staticPressure : Pressure;
        attribute flowRate : VolumeFlowRate;
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute power : Power;
        attribute frequency : Real;
    }

    item def RotationalMechanicalPower {
        attribute speed : RotationalSpeed;
        attribute torque : Torque;
        attribute power : Power;
    }

    item def StartCommand {
        attribute requestedSpeed : RotationalSpeed;
        attribute rampTime : TimeDuration;
    }

    item def StopCommand {
        attribute controlledStop : Boolean;
    }

    item def SpeedSetpoint {
        attribute targetSpeed : RotationalSpeed;
    }

    item def Telemetry {
        attribute measuredSpeed : RotationalSpeed;
        attribute measuredFlow : VolumeFlowRate;
        attribute measuredPressureRise : PressureRise;
        attribute measuredVibration : VibrationVelocity;
        attribute measuredPower : Power;
        attribute healthy : Boolean;
    }

    item def FaultSignal {
        attribute overspeed : Boolean;
        attribute lowFlow : Boolean;
        attribute highVibration : Boolean;
        attribute sealLeak : Boolean;
        attribute motorOverload : Boolean;
    }

    port def FluidPort {
        inout item fluid : WorkingFluid;
        attribute nominalPressureRating : Pressure;
        attribute nominalFlowRating : VolumeFlowRate;
    }

    port def ElectricalPowerPort {
        in item powerIn : ElectricalPower;
    }

    port def RotationalPowerPort {
        inout item rotationalPower : RotationalMechanicalPower;
    }

    port def CommandPort {
        in item start : StartCommand;
        in item stop : StopCommand;
        in item speedSetpoint : SpeedSetpoint;
    }

    port def TelemetryPort {
        out item telemetry : Telemetry;
        out item fault : FaultSignal;
    }

    port def SensorSignalPort {
        out item telemetry : Telemetry;
    }

    port def FaultInputPort {
        in item fault : FaultSignal;
    }

    part def ImpellerBlade {
        attribute bladeIndex : Integer;
        attribute inletAngle : Angle;
        attribute outletAngle : Angle;
        attribute chordLength : Length;
        attribute height : Length;
        attribute surfaceRoughness : Clearance;
    }

    part def ImpellerHub {
        attribute hubDiameter : Diameter;
        attribute boreDiameter : Diameter;
        attribute axialLength : Length;
        attribute material : String = "stainless steel";
        port shaftInterface : RotationalPowerPort;
    }

    part def Impeller {
        doc /* The impeller is the primary energy-transfer element. Its function is to receive rotational mechanical power through the shaft and impart kinetic energy to the working fluid, increasing fluid velocity and enabling downstream pressure rise in the surrounding casing. */

        attribute outerDiameter : Diameter;
        attribute inletEyeDiameter : Diameter;
        attribute bladeCount : Integer = 6;
        attribute designSpeed : RotationalSpeed;
        attribute maximumAllowableSpeed : RotationalSpeed;
        attribute mass : Mass;
        attribute nominalEfficiency : Efficiency;
        attribute designFlow : VolumeFlowRate;
        attribute designPressureRise : PressureRise;
        attribute frontWearRingClearance : Clearance;
        attribute rearWearRingClearance : Clearance;

        port eye : FluidPort;
        port dischargePeriphery : FluidPort;
        port driveShaft : RotationalPowerPort;

        part hub : ImpellerHub;
        part blade1 : ImpellerBlade { attribute bladeIndex = 1; }
        part blade2 : ImpellerBlade { attribute bladeIndex = 2; }
        part blade3 : ImpellerBlade { attribute bladeIndex = 3; }
        part blade4 : ImpellerBlade { attribute bladeIndex = 4; }
        part blade5 : ImpellerBlade { attribute bladeIndex = 5; }
        part blade6 : ImpellerBlade { attribute bladeIndex = 6; }

        connect driveShaft to hub.shaftInterface;
    }

    part def VoluteCasing {
        doc /* The volute casing receives high-velocity flow from the impeller periphery and converts a portion of velocity head into static pressure at the outlet. */

        attribute casingMaterial : String = "ductile iron";
        attribute pressureRating : Pressure;
        attribute tongueClearance : Clearance;
        attribute internalWettedArea : Area;

        port suctionNozzle : FluidPort;
        port impellerEyeInterface : FluidPort;
        port impellerPeripheryInterface : FluidPort;
        port dischargeNozzle : FluidPort;

        connect suctionNozzle to impellerEyeInterface;
        connect impellerPeripheryInterface to dischargeNozzle;
    }

    part def Shaft {
        attribute diameter : Diameter;
        attribute length : Length;
        attribute material : String = "17-4PH stainless steel";
        attribute allowableTorque : Torque;

        port motorEnd : RotationalPowerPort;
        port impellerEnd : RotationalPowerPort;

        connect motorEnd to impellerEnd;
    }

    part def BearingAssembly {
        attribute radialLoadCapacity : Real;
        attribute axialLoadCapacity : Real;
        attribute lubricant : String = "sealed grease";
        attribute expectedLife : TimeDuration;

        port shaftSupport : RotationalPowerPort;
    }

    part def MechanicalSeal {
        attribute sealType : String = "single mechanical seal";
        attribute maximumSealPressure : Pressure;
        attribute maximumSealTemperature : Temperature;
        attribute leakageLimit : VolumeFlowRate;

        port processSide : FluidPort;
    }

    part def ElectricMotor {
        attribute ratedPower : Power;
        attribute ratedVoltage : Voltage;
        attribute ratedCurrent : Current;
        attribute ratedSpeed : RotationalSpeed;
        attribute ratedTorque : Torque;
        attribute motorEfficiency : Efficiency;

        port electricalSupply : ElectricalPowerPort;
        port shaftOutput : RotationalPowerPort;
        port commandInput : CommandPort;
        port statusOutput : TelemetryPort;
    }

    part def VariableSpeedController {
        attribute controlMode : String = "closed-loop speed control";
        attribute minimumSpeed : RotationalSpeed;
        attribute maximumSpeed : RotationalSpeed;
        attribute accelerationLimit : Real;
        attribute decelerationLimit : Real;

        port powerInput : ElectricalPowerPort;
        port motorCommand : CommandPort;
        port motorFeedback : FaultInputPort;
        port operatorCommand : CommandPort;
        port systemTelemetry : TelemetryPort;
    }

    part def FlowSensor {
        attribute measurementRange : VolumeFlowRate;
        attribute accuracyPercentOfReading : Real;

        port sensedFluid : FluidPort;
        port signal : SensorSignalPort;
    }

    part def PressureSensor {
        attribute measurementRange : Pressure;
        attribute accuracyPercentFullScale : Real;

        port sensedFluid : FluidPort;
        port signal : SensorSignalPort;
    }

    part def SpeedSensor {
        attribute measurementRange : RotationalSpeed;
        attribute accuracyRpm : RotationalSpeed;

        port sensedShaft : RotationalPowerPort;
        port signal : SensorSignalPort;
    }

    part def VibrationSensor {
        attribute measurementRange : VibrationVelocity;
        attribute alarmThreshold : VibrationVelocity;
        attribute tripThreshold : VibrationVelocity;

        port signal : SensorSignalPort;
    }

    action def AccelerateImpeller {
        in item command : StartCommand;
        in item electricalPower : ElectricalPower;
        out item rotationalPower : RotationalMechanicalPower;

        attribute finalSpeed : RotationalSpeed;
        attribute accelerationTime : TimeDuration;
    }

    action def ImpartEnergyToFluid {
        doc /* Primary function behavior: convert shaft power supplied to the impeller into increased kinetic energy of the working fluid. */

        in item incomingFluid : WorkingFluid;
        in item shaftPower : RotationalMechanicalPower;
        out item energizedFluid : WorkingFluid;

        attribute achievedFlowRate : VolumeFlowRate;
        attribute achievedPressureRise : PressureRise;
        attribute hydraulicPower : Power;
        attribute conversionEfficiency : Efficiency;
    }

    action def DiffuseFlowInVolute {
        in item energizedFluid : WorkingFluid;
        out item pressurizedFluid : WorkingFluid;

        attribute velocityHeadRecoveredAsPressure : Pressure;
    }

    action def RegulateImpellerSpeed {
        in item setpoint : SpeedSetpoint;
        in item telemetry : Telemetry;
        out item correctedCommand : SpeedSetpoint;

        attribute speedError : RotationalSpeed;
    }

    action def DetectFaults {
        in item telemetry : Telemetry;
        out item fault : FaultSignal;

        attribute overspeedTripLimit : RotationalSpeed;
        attribute vibrationTripLimit : VibrationVelocity;
        attribute minimumContinuousFlow : VolumeFlowRate;
    }

    action def ControlledStop {
        in item stop : StopCommand;
        out item stoppedTelemetry : Telemetry;

        attribute coastDownTime : TimeDuration;
    }

    state def ImpellerSystemOperatingStates {
        entry action DetectFaults;

        state Stopped;
        state Starting;
        state Running;
        state Regulating;
        state Stopping;
        state Faulted;

        transition initial then Stopped;

        transition StartRequested
            from Stopped
            to Starting
            accept StartCommand
            then AccelerateImpeller;

        transition StartupComplete
            from Starting
            to Running;

        transition SetpointChanged
            from Running
            to Regulating
            accept SpeedSetpoint
            then RegulateImpellerSpeed;

        transition RegulationComplete
            from Regulating
            to Running;

        transition StopRequested
            from Running
            to Stopping
            accept StopCommand
            then ControlledStop;

        transition StopFromRegulating
            from Regulating
            to Stopping
            accept StopCommand
            then ControlledStop;

        transition StoppedConfirmed
            from Stopping
            to Stopped;

        transition FaultDetectedFromStarting
            from Starting
            to Faulted
            accept FaultSignal;

        transition FaultDetectedFromRunning
            from Running
            to Faulted
            accept FaultSignal;

        transition FaultDetectedFromRegulating
            from Regulating
            to Faulted
            accept FaultSignal;

        transition ResetAfterFault
            from Faulted
            to Stopped
            accept StopCommand;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall use an impeller as its primary functional element to transfer rotational mechanical energy into a continuous fluid stream, producing a specified flow rate and pressure rise at the discharge outlet. */
        subject system : ImpellerFluidMover;

        require constraint {
            system.nominalFlow.value >= 0.050 and
            system.nominalPressureRise.value >= 120000.0
        }
    }

    requirement def EnergyConversionRequirement {
        doc /* The impeller shall convert supplied shaft power into hydraulic power with not less than the specified overall efficiency at the design operating point. */
        subject system : ImpellerFluidMover;

        require constraint {
            system.overallEfficiency.value >= 0.65
        }
    }

    requirement def SpeedLimitRequirement {
        doc /* The controller shall prevent operation of the impeller above the maximum allowable rotational speed. */
        subject system : ImpellerFluidMover;

        require constraint {
            system.operatingSpeed.value <= system.impeller.maximumAllowableSpeed.value
        }
    }

    requirement def ContainmentRequirement {
        doc /* The casing and seal boundary shall contain the working fluid at the rated discharge pressure without external leakage above the leakage limit. */
        subject system : ImpellerFluidMover;

        require constraint {
            system.casing.pressureRating.value >= system.maximumDischargePressure.value and
            system.seal.leakageLimit.value <= 0.000001
        }
    }

    requirement def MonitoringRequirement {
        doc /* The system shall provide telemetry for rotational speed, flow rate, pressure rise, vibration level, power draw, and health state during operation. */
        subject system : ImpellerFluidMover;

        require constraint {
            system.telemetryAvailable == true
        }
    }

    requirement def VibrationProtectionRequirement {
        doc /* The system shall enter the faulted state when measured vibration exceeds the trip threshold. */
        subject system : ImpellerFluidMover;

        require constraint {
            system.vibrationProtectionEnabled == true
        }
    }

    part def ImpellerFluidMover {
        doc /* High-level system: an impeller-based fluid mover that draws working fluid through an inlet, accelerates it using a rotating impeller, and discharges the fluid at increased pressure and flow. */

        attribute nominalFlow : VolumeFlowRate;
        attribute nominalPressureRise : PressureRise;
        attribute maximumDischargePressure : Pressure;
        attribute operatingSpeed : RotationalSpeed;
        attribute overallEfficiency : Efficiency;
        attribute telemetryAvailable : Boolean = true;
        attribute vibrationProtectionEnabled : Boolean = true;

        port fluidInlet : FluidPort;
        port fluidOutlet : FluidPort;
        port electricalInput : ElectricalPowerPort;
        port operatorInterface : CommandPort;
        port telemetryOutput : TelemetryPort;

        part controller : VariableSpeedController;
        part motor : ElectricMotor;
        part shaft : Shaft;
        part impeller : Impeller;
        part casing : VoluteCasing;
        part bearingDriveEnd : BearingAssembly;
        part bearingNonDriveEnd : BearingAssembly;
        part seal : MechanicalSeal;
        part inletFlowSensor : FlowSensor;
        part inletPressureSensor : PressureSensor;
        part dischargePressureSensor : PressureSensor;
        part speedSensor : SpeedSensor;
        part vibrationSensor : VibrationSensor;

        connect electricalInput to controller.powerInput;
        connect operatorInterface to controller.operatorCommand;
        connect controller.motorCommand to motor.commandInput;
        connect motor.statusOutput to controller.motorFeedback;
        connect controller.systemTelemetry to telemetryOutput;

        connect controller.powerInput to motor.electricalSupply;

        connect motor.shaftOutput to shaft.motorEnd;
        connect shaft.impellerEnd to impeller.driveShaft;
        connect shaft.motorEnd to bearingDriveEnd.shaftSupport;
        connect shaft.impellerEnd to bearingNonDriveEnd.shaftSupport;
        connect speedSensor.sensedShaft to shaft.impellerEnd;

        connect fluidInlet to inletFlowSensor.sensedFluid;
        connect fluidInlet to inletPressureSensor.sensedFluid;
        connect fluidInlet to casing.suctionNozzle;
        connect casing.impellerEyeInterface to impeller.eye;
        connect impeller.dischargePeriphery to casing.impellerPeripheryInterface;
        connect casing.dischargeNozzle to dischargePressureSensor.sensedFluid;
        connect casing.dischargeNozzle to fluidOutlet;
        connect seal.processSide to casing.impellerEyeInterface;

        perform action accelerate : AccelerateImpeller;
        perform action primaryEnergyTransfer : ImpartEnergyToFluid;
        perform action voluteDiffusion : DiffuseFlowInVolute;
        perform action speedRegulation : RegulateImpellerSpeed;
        perform action faultDetection : DetectFaults;
        perform action shutdown : ControlledStop;

        exhibit state operatingState : ImpellerSystemOperatingStates;

        satisfy PrimaryFunctionRequirement;
        satisfy EnergyConversionRequirement;
        satisfy SpeedLimitRequirement;
        satisfy ContainmentRequirement;
        satisfy MonitoringRequirement;
        satisfy VibrationProtectionRequirement;
    }

    part impellerBasedFluidMover : ImpellerFluidMover {
        attribute nominalFlow : VolumeFlowRate {
            attribute value = 0.075;
            attribute unit = "m^3/s";
        }

        attribute nominalPressureRise : PressureRise {
            attribute value = 180000.0;
            attribute unit = "Pa";
        }

        attribute maximumDischargePressure : Pressure {
            attribute value = 600000.0;
            attribute unit = "Pa";
        }

        attribute operatingSpeed : RotationalSpeed {
            attribute value = 1800.0;
            attribute unit = "rpm";
        }

        attribute overallEfficiency : Efficiency {
            attribute value = 0.72;
            attribute unit = "1";
        }

        part impeller {
            attribute outerDiameter : Diameter {
                attribute value = 0.32;
                attribute unit = "m";
            }

            attribute inletEyeDiameter : Diameter {
                attribute value = 0.15;
                attribute unit = "m";
            }

            attribute designSpeed : RotationalSpeed {
                attribute value = 1800.0;
                attribute unit = "rpm";
            }

            attribute maximumAllowableSpeed : RotationalSpeed {
                attribute value = 2400.0;
                attribute unit = "rpm";
            }

            attribute mass : Mass {
                attribute value = 18.0;
                attribute unit = "kg";
            }

            attribute nominalEfficiency : Efficiency {
                attribute value = 0.78;
                attribute unit = "1";
            }

            attribute designFlow : VolumeFlowRate {
                attribute value = 0.075;
                attribute unit = "m^3/s";
            }

            attribute designPressureRise : PressureRise {
                attribute value = 180000.0;
                attribute unit = "Pa";
            }

            attribute frontWearRingClearance : Clearance {
                attribute value = 0.35;
                attribute unit = "mm";
            }

            attribute rearWearRingClearance : Clearance {
                attribute value = 0.40;
                attribute unit = "mm";
            }
        }

        part casing {
            attribute pressureRating : Pressure {
                attribute value = 1000000.0;
                attribute unit = "Pa";
            }

            attribute tongueClearance : Clearance {
                attribute value = 2.0;
                attribute unit = "mm";
            }

            attribute internalWettedArea : Area {
                attribute value = 0.85;
                attribute unit = "m^2";
            }
        }

        part motor {
            attribute ratedPower : Power {
                attribute value = 22000.0;
                attribute unit = "W";
            }

            attribute ratedVoltage : Voltage {
                attribute value = 480.0;
                attribute unit = "V";
            }

            attribute ratedCurrent : Current {
                attribute value = 34.0;
                attribute unit = "A";
            }

            attribute ratedSpeed : RotationalSpeed {
                attribute value = 1800.0;
                attribute unit = "rpm";
            }

            attribute ratedTorque : Torque {
                attribute value = 116.7;
                attribute unit = "N*m";
            }

            attribute motorEfficiency : Efficiency {
                attribute value = 0.91;
                attribute unit = "1";
            }
        }

        part shaft {
            attribute diameter : Diameter {
                attribute value = 0.045;
                attribute unit = "m";
            }

            attribute length : Length {
                attribute value = 0.62;
                attribute unit = "m";
            }

            attribute allowableTorque : Torque {
                attribute value = 280.0;
                attribute unit = "N*m";
            }
        }

        part controller {
            attribute minimumSpeed : RotationalSpeed {
                attribute value = 600.0;
                attribute unit = "rpm";
            }

            attribute maximumSpeed : RotationalSpeed {
                attribute value = 2400.0;
                attribute unit = "rpm";
            }

            attribute accelerationLimit = 300.0;
            attribute decelerationLimit = 400.0;
        }

        part seal {
            attribute maximumSealPressure : Pressure {
                attribute value = 700000.0;
                attribute unit = "Pa";
            }

            attribute maximumSealTemperature : Temperature {
                attribute value = 90.0;
                attribute unit = "degC";
            }

            attribute leakageLimit : VolumeFlowRate {
                attribute value = 0.000001;
                attribute unit = "m^3/s";
            }
        }

        part vibrationSensor {
            attribute alarmThreshold : VibrationVelocity {
                attribute value = 4.5;
                attribute unit = "mm/s";
            }

            attribute tripThreshold : VibrationVelocity {
                attribute value = 7.1;
                attribute unit = "mm/s";
            }
        }
    }

}
