package ClothesDryerSystem {

    import ScalarValues::*;
    import SI::*;

    item def WetLaundry {
        attribute dryMass: Real;
        attribute waterMass: Real;
        attribute fabricTemperature: Real;
        attribute targetMoistureRatio: Real;
    }

    item def DryLaundry {
        attribute dryMass: Real;
        attribute residualWaterMass: Real;
        attribute finalTemperature: Real;
    }

    item def MoistAir {
        attribute temperatureC: Real;
        attribute relativeHumidityPercent: Real;
        attribute volumetricFlowRate_m3_per_min: Real;
    }

    item def ElectricalEnergy {
        attribute voltage_V: Real;
        attribute current_A: Real;
        attribute frequency_Hz: Real;
        attribute power_W: Real;
    }

    item def UserCommand {
        attribute selectedCycle: CycleKind;
        attribute drynessTarget: DrynessLevel;
        attribute startRequested: Boolean;
        attribute cancelRequested: Boolean;
    }

    enum def CycleKind {
        enum normal;
        enum delicate;
        enum heavyDuty;
        enum airFluff;
        enum timedDry;
    }

    enum def DrynessLevel {
        enum damp;
        enum normalDry;
        enum extraDry;
    }

    enum def DoorPosition {
        enum open;
        enum closed;
        enum latched;
    }

    enum def DryerMode {
        enum off;
        enum idle;
        enum ready;
        enum drying;
        enum cooldown;
        enum complete;
        enum fault;
    }

    port def LaundryInputPort {
        in item laundry: WetLaundry;
    }

    port def LaundryOutputPort {
        out item laundry: DryLaundry;
    }

    port def ExhaustAirPort {
        out item exhaust: MoistAir;
    }

    port def AirIntakePort {
        in item roomAir: MoistAir;
    }

    port def ElectricalPowerPort {
        in item power: ElectricalEnergy;
    }

    port def UserInterfacePort {
        in item command: UserCommand;
        out attribute remainingTime_min: Real;
        out attribute currentMode: DryerMode;
        out attribute faultCode: String;
    }

    port def DoorAccessPort {
        in attribute doorPosition: DoorPosition;
        out attribute drumAccessible: Boolean;
    }

    port def ThermalControlPort {
        out attribute heaterEnabled: Boolean;
        out attribute targetAirTemperatureC: Real;
        in attribute measuredAirTemperatureC: Real;
    }

    port def MotorControlPort {
        out attribute motorEnabled: Boolean;
        out attribute drumSpeed_rpm: Real;
        in attribute motorCurrent_A: Real;
    }

    part def ClothesDryer {
        attribute ratedCapacity_kg: Real = 8.0;
        attribute nominalVoltage_V: Real = 240.0;
        attribute maximumPower_W: Real = 5600.0;
        attribute drumVolume_L: Real = 115.0;
        attribute exhaustFlow_m3_per_min: Real = 3.2;
        attribute targetExhaustTemperatureC: Real = 63.0;
        attribute cooldownTemperatureC: Real = 38.0;
        attribute currentMode: DryerMode = DryerMode::off;
        attribute primaryFunction: String = "Remove moisture from wet laundry by tumbling it in a controlled flow of heated air and exhausting moisture-laden air until the selected dryness target is reached.";

        port laundryIn: LaundryInputPort;
        port laundryOut: LaundryOutputPort;
        port airIn: AirIntakePort;
        port exhaustOut: ExhaustAirPort;
        port electricalIn: ElectricalPowerPort;
        port userInterface: UserInterfacePort;
        port doorAccess: DoorAccessPort;

        part drum: Drum;
        part heater: ElectricHeater;
        part blower: Blower;
        part driveMotor: DriveMotor;
        part beltDrive: BeltDrive;
        part door: DoorAssembly;
        part lintFilter: LintFilter;
        part moistureSensor: MoistureSensor;
        part temperatureSensor: TemperatureSensor;
        part controller: DryerController;

        connect electricalIn to heater.powerIn;
        connect electricalIn to driveMotor.powerIn;
        connect controller.heaterControl to heater.controlIn;
        connect controller.motorControl to driveMotor.controlIn;
        connect controller.thermalFeedback to temperatureSensor.measurementOut;
        connect controller.moistureFeedback to moistureSensor.measurementOut;
        connect controller.userPort to userInterface;
        connect door.statusOut to controller.doorStatusIn;
        connect airIn to blower.airIn;
        connect blower.airOut to heater.airIn;
        connect heater.airOut to drum.processAirIn;
        connect drum.processAirOut to lintFilter.airIn;
        connect lintFilter.airOut to exhaustOut;
        connect driveMotor.shaftOut to beltDrive.motorSide;
        connect beltDrive.drumSide to drum.rotationIn;
        connect laundryIn to drum.laundryIn;
        connect drum.laundryOut to laundryOut;

        perform action dryLaundry: DryLaundryAction;
        exhibit state dryerStates: DryerStateMachine;
    }

    part def Drum {
        attribute volume_L: Real = 115.0;
        attribute nominalSpeed_rpm: Real = 52.0;
        attribute rotationReversalPeriod_s: Real = 120.0;

        port laundryIn: LaundryInputPort;
        port laundryOut: LaundryOutputPort;
        port processAirIn: AirIntakePort;
        port processAirOut: ExhaustAirPort;
        port rotationIn: MotorControlPort;
    }

    part def ElectricHeater {
        attribute ratedPower_W: Real = 5200.0;
        attribute maximumOutletTemperatureC: Real = 85.0;

        port powerIn: ElectricalPowerPort;
        port airIn: AirIntakePort;
        port airOut: ExhaustAirPort;
        port controlIn: ThermalControlPort;
    }

    part def Blower {
        attribute ratedFlow_m3_per_min: Real = 3.2;
        attribute pressureRise_Pa: Real = 190.0;

        port airIn: AirIntakePort;
        port airOut: ExhaustAirPort;
    }

    part def DriveMotor {
        attribute ratedPower_W: Real = 370.0;
        attribute ratedSpeed_rpm: Real = 1725.0;

        port powerIn: ElectricalPowerPort;
        port controlIn: MotorControlPort;
        port shaftOut: MotorControlPort;
    }

    part def BeltDrive {
        attribute speedReductionRatio: Real = 33.2;
        attribute efficiencyPercent: Real = 92.0;

        port motorSide: MotorControlPort;
        port drumSide: MotorControlPort;
    }

    part def DoorAssembly {
        attribute position: DoorPosition = DoorPosition::closed;
        attribute latchEngaged: Boolean = false;

        port access: DoorAccessPort;
        port statusOut: DoorAccessPort;
    }

    part def LintFilter {
        attribute nominalParticleCapturePercent: Real = 85.0;
        attribute serviceIntervalCycles: Integer = 1;

        port airIn: AirIntakePort;
        port airOut: ExhaustAirPort;
    }

    part def MoistureSensor {
        attribute measuredMoistureRatio: Real;
        attribute measurementTolerancePercent: Real = 5.0;

        port measurementOut {
            out attribute moistureRatio: Real;
        }
    }

    part def TemperatureSensor {
        attribute measuredTemperatureC: Real;
        attribute responseTime_s: Real = 3.0;
        attribute measurementToleranceC: Real = 2.0;

        port measurementOut {
            out attribute temperatureC: Real;
        }
    }

    part def DryerController {
        attribute selectedCycle: CycleKind = CycleKind::normal;
        attribute selectedDryness: DrynessLevel = DrynessLevel::normalDry;
        attribute remainingTime_min: Real = 0.0;
        attribute estimatedMoistureRatio: Real = 1.0;
        attribute faultCode: String = "";

        port userPort: UserInterfacePort;
        port heaterControl: ThermalControlPort;
        port motorControl: MotorControlPort;
        port doorStatusIn: DoorAccessPort;
        port thermalFeedback {
            in attribute temperatureC: Real;
        }
        port moistureFeedback {
            in attribute moistureRatio: Real;
        }

        perform action selectCycle: SelectCycleAction;
        perform action regulateHeat: RegulateHeatAction;
        perform action controlTumble: ControlTumbleAction;
        perform action determineDryness: DetermineDrynessAction;
    }

    action def DryLaundryAction {
        in item load: WetLaundry;
        in attribute cycle: CycleKind;
        in attribute target: DrynessLevel;
        out item result: DryLaundry;

        action acceptLoad;
        action verifyDoorLatched;
        action tumbleLoad;
        action heatAir;
        action evaporateMoisture;
        action exhaustMoistAir;
        action senseDryness;
        action cooldownLoad;
        action signalComplete;

        flow acceptLoad then verifyDoorLatched;
        flow verifyDoorLatched then tumbleLoad;
        flow tumbleLoad then heatAir;
        flow heatAir then evaporateMoisture;
        flow evaporateMoisture then exhaustMoistAir;
        flow exhaustMoistAir then senseDryness;
        flow senseDryness then cooldownLoad;
        flow cooldownLoad then signalComplete;
    }

    action def SelectCycleAction {
        in item command: UserCommand;
        out attribute cycle: CycleKind;
        out attribute dryness: DrynessLevel;
    }

    action def RegulateHeatAction {
        in attribute measuredTemperatureC: Real;
        in attribute targetTemperatureC: Real;
        out attribute heaterEnabled: Boolean;
    }

    action def ControlTumbleAction {
        in attribute doorPosition: DoorPosition;
        in attribute requestedSpeed_rpm: Real;
        out attribute motorEnabled: Boolean;
        out attribute drumSpeed_rpm: Real;
    }

    action def DetermineDrynessAction {
        in attribute measuredMoistureRatio: Real;
        in attribute targetMoistureRatio: Real;
        out attribute dryEnough: Boolean;
    }

    state def DryerStateMachine {
        state off;
        state idle;
        state ready;
        state drying;
        state cooldown;
        state complete;
        state fault;

        transition initial then off;
        transition powerApplied first off then idle;
        transition loadInserted first idle then ready;
        transition startPressed first ready then drying;
        transition drynessReached first drying then cooldown;
        transition cooldownComplete first cooldown then complete;
        transition doorOpenedAfterComplete first complete then idle;
        transition cancelPressed first drying then idle;
        transition overTemperature first drying then fault;
        transition doorOpenedWhileRunning first drying then fault;
        transition faultCleared first fault then idle;
    }

    requirement def PrimaryFunctionRequirement {
        subject dryer: ClothesDryer;

        doc /* The clothes dryer shall remove moisture from wet laundry by tumbling the load in a rotating drum while circulating heated air through the load and exhausting moisture-laden air. */
    }

    requirement def CapacityRequirement {
        subject dryer: ClothesDryer;

        doc /* The clothes dryer shall dry a cotton laundry load with dry mass up to 8.0 kg without exceeding rated electrical power. */
    }

    requirement def DrynessRequirement {
        subject dryer: ClothesDryer;

        doc /* For a normal cycle with normal dry target, the clothes dryer shall reduce laundry moisture ratio to 0.05 kg water per kg dry fabric or less before declaring the cycle complete. */
    }

    requirement def ThermalSafetyRequirement {
        subject dryer: ClothesDryer;

        doc /* The clothes dryer shall disable the heater if measured exhaust air temperature exceeds 85 degrees Celsius. */
    }

    requirement def DoorInterlockRequirement {
        subject dryer: ClothesDryer;

        doc /* The clothes dryer shall prevent motor rotation and heater operation whenever the door is open or unlatched. */
    }

    requirement def CooldownRequirement {
        subject dryer: ClothesDryer;

        doc /* After drying is complete, the clothes dryer shall tumble without heat until measured outlet air temperature is no greater than 38 degrees Celsius. */
    }

    requirement def ExhaustRequirement {
        subject dryer: ClothesDryer;

        doc /* The clothes dryer shall provide an exhaust airflow of at least 3.0 cubic meters per minute during heated drying. */
    }

    part dryerSystem: ClothesDryer;

}