package 'Odon Device Model' {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    private import Time::*;

    alias Pressure for ISQ::PressureValue;
    alias TractionForce for ISQ::ForceValue;
    alias TractionAngle for ISQ::PlaneAngleValue;
    alias VolumeFlowRate for ISQ::VolumeFlowRateValue;

    item def AirFlow {
        attribute flowRate : VolumeFlowRate;
    }

    item def Command {
        attribute commandValue : ScalarValues::Real;
    }

    item def PressureReading {
        attribute pressure : Pressure;
        attribute timestamp : ISQ::TimeValue;
    }

    item def TractionSample {
        attribute force : TractionForce;
        attribute angle : TractionAngle;
    }

    item def TractionReading {
        attribute force : TractionForce;
        attribute angle : TractionAngle;
        attribute timestamp : ISQ::TimeValue;
    }

    item def AlarmSignal {
        attribute active : Boolean;
    }

    port def AirFlowPort {
        item air : AirFlow;
    }

    port def CommandPort {
        item command : Command;
    }

    port def PressurePort {
        item pressure : Pressure;
    }

    port def TractionPort {
        item sample : TractionSample;
    }

    port def PressureReadingPort {
        item reading : PressureReading;
    }

    port def TractionReadingPort {
        item reading : TractionReading;
    }

    port def AlarmPort {
        item alarm : AlarmSignal;
    }

    action def GenerateAirFlow {
        in cmd : Command;
        out airOut : AirFlow;
    }

    action def RegulatePressure {
        in inletAir : AirFlow;
        in cmd : Command;
        out outletAir : AirFlow;
    }

    action def VentExcessPressure {
        in cmd : Command;
        out ventedAir : AirFlow;
    }

    action def InflateSleeve {
        in airIn : AirFlow;
        in targetPressure : Pressure;
        out pressure : Pressure;
    }

    action def PositionOnHead {
        in headDiameter : ISQ::LengthValue;
        out positioned : Boolean;
    }

    action def ApplyTraction {
        in force : TractionForce;
        in angle : TractionAngle;
        out sample : TractionSample;
    }

    action def SensePressure {
        in pressure : Pressure;
        out reading : PressureReading;
    }

    action def SenseTraction {
        in sample : TractionSample;
        out reading : TractionReading;
    }

    action def MonitorSafety {
        in pressureReadingValue : PressureReading;
        in tractionReadingValue : TractionReading;
        in maxPressure : Pressure;
        in maxTractionForce : TractionForce;
        out overPressureAlarm : AlarmSignal;
        out overForceAlarm : AlarmSignal;
    }

    action def ComputeControlCommands {
        in pressureReadingValue : PressureReading;
        in tractionReadingValue : TractionReading;
        in maxPressure : Pressure;
        in maxTractionForce : TractionForce;
        out pumpCmd : Command;
        out regulatorCmd : Command;
        out valveCmd : Command;
    }

    attribute def StartProcedure;
    attribute def PositioningComplete;
    attribute def TargetPressureReached;
    attribute def GripEstablished;
    attribute def TractionComplete;
    attribute def DeliveryComplete;

    state def OdonProcedureStates;

    part def AirPump {
        out port supply : AirFlowPort;
        in port command : CommandPort;
        perform action generateAir : GenerateAirFlow;
        bind generateAir.cmd = command.command;
        bind generateAir.airOut = supply.air;
    }

    part def PressureRegulator {
        in port inlet : AirFlowPort;
        out port outlet : AirFlowPort;
        in port command : CommandPort;
        perform action regulate : RegulatePressure;
        bind regulate.inletAir = inlet.air;
        bind regulate.cmd = command.command;
        bind regulate.outletAir = outlet.air;
    }

    part def SafetyValve {
        in port inlet : AirFlowPort;
        out port vent : AirFlowPort;
        in port command : CommandPort;
        perform action ventExcess : VentExcessPressure;
        bind ventExcess.cmd = command.command;
        bind ventExcess.ventedAir = vent.air;
    }

    part def InflatableSleeve {
        in port airInlet : AirFlowPort;
        out port pressureSense : PressurePort;
        attribute currentPressure : Pressure;
        attribute targetPressure : Pressure = 60 [kPa];
        perform action inflate : InflateSleeve;
        bind inflate.airIn = airInlet.air;
        bind inflate.targetPressure = targetPressure;
        bind inflate.pressure = pressureSense.pressure;
    }

    part def CupShapedApplicator {
        part sleeve : InflatableSleeve;
        perform action positionOnHead : PositionOnHead;
    }

    part def TractionHandle {
        out port tractionOut : TractionPort;
        attribute appliedForce : TractionForce = 0 [N];
        attribute appliedAngle : TractionAngle = 0 [deg];
        perform action pull : ApplyTraction;
        bind pull.force = appliedForce;
        bind pull.angle = appliedAngle;
        bind pull.sample = tractionOut.sample;
    }

    part def PressureSensor {
        in port sense : PressurePort;
        out port reading : PressureReadingPort;
        perform action sensePressure : SensePressure;
        bind sensePressure.pressure = sense.pressure;
        bind sensePressure.reading = reading.reading;
    }

    part def TractionForceSensor {
        in port sense : TractionPort;
        out port reading : TractionReadingPort;
        perform action senseTraction : SenseTraction;
        bind senseTraction.sample = sense.sample;
        bind senseTraction.reading = reading.reading;
    }

    part def ControlUnit {
        in port pressureReading : PressureReadingPort;
        in port tractionReading : TractionReadingPort;
        out port pumpCommand : CommandPort;
        out port regulatorCommand : CommandPort;
        out port valveCommand : CommandPort;
        out port pressureAlarm : AlarmPort;
        out port forceAlarm : AlarmPort;
        attribute maxPressure : Pressure = 60 [kPa];
        attribute maxTractionForce : TractionForce = 250 [N];
        perform action monitor : MonitorSafety;
        bind monitor.pressureReadingValue = pressureReading.reading;
        bind monitor.tractionReadingValue = tractionReading.reading;
        bind monitor.maxPressure = maxPressure;
        bind monitor.maxTractionForce = maxTractionForce;
        bind monitor.overPressureAlarm = pressureAlarm.alarm;
        bind monitor.overForceAlarm = forceAlarm.alarm;
        perform action computeCommands : ComputeControlCommands;
        bind computeCommands.pressureReadingValue = pressureReading.reading;
        bind computeCommands.tractionReadingValue = tractionReading.reading;
        bind computeCommands.maxPressure = maxPressure;
        bind computeCommands.maxTractionForce = maxTractionForce;
        bind computeCommands.pumpCmd = pumpCommand.command;
        bind computeCommands.regulatorCmd = regulatorCommand.command;
        bind computeCommands.valveCmd = valveCommand.command;
    }

    part def OdonDevice {
        part applicator : CupShapedApplicator;
        part pump : AirPump;
        part regulator : PressureRegulator;
        part safetyValve : SafetyValve;
        part handle : TractionHandle;
        part pressureSensor : PressureSensor;
        part tractionSensor : TractionForceSensor;
        part controller : ControlUnit;

        connect pump.supply to regulator.inlet;
        connect regulator.outlet to applicator.sleeve.airInlet;
        connect regulator.outlet to safetyValve.inlet;
        connect applicator.sleeve.pressureSense to pressureSensor.sense;
        connect handle.tractionOut to tractionSensor.sense;
        connect pressureSensor.reading to controller.pressureReading;
        connect tractionSensor.reading to controller.tractionReading;
        connect controller.pumpCommand to pump.command;
        connect controller.regulatorCommand to regulator.command;
        connect controller.valveCommand to safetyValve.command;

        exhibit state procedure : OdonProcedureStates {
            entry action initial { }
            transition initial then idle;
            state idle;
            transition 'idle-positioning'
                first idle
                accept StartProcedure
                then positioning;
            state positioning;
            transition 'positioning-inflating'
                first positioning
                accept PositioningComplete
                then inflating;
            state inflating;
            transition 'inflating-gripping'
                first inflating
                accept TargetPressureReached
                then gripping;
            state gripping;
            transition 'gripping-traction'
                first gripping
                accept GripEstablished
                then applyingTraction;
            state applyingTraction;
            transition 'traction-deflating'
                first applyingTraction
                accept TractionComplete
                then deflating;
            state deflating;
            transition 'deflating-removing'
                first deflating
                accept DeliveryComplete
                then removing;
            state removing;
        }
    }

    requirement def 'Pressure Safety' {
        attribute maxPressure : Pressure;
    }

    requirement def 'Traction Force Safety' {
        attribute maxTractionForce : TractionForce;
    }

    requirement 'Pressure Safety Limit' {
        attribute maxPressure : Pressure = 60 [kPa];
    }

    requirement 'Traction Force Safety Limit' {
        attribute maxTractionForce : TractionForce = 250 [N];
    }
}
