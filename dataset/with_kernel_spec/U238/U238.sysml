package HeatingPadSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    private import Time::*;

    enum def HeatLevel {
        off;
        low;
        medium;
        high;
    }

    item def HeatLevelCommand {
        attribute level : HeatLevel;
    }

    item def PowerCommand {
        attribute dutyCycle : Real;
    }

    item def ShutdownSignal;

    port def ACInputPort;

    port def DCPowerPort {
        out power : PowerValue;
    }

    port def DCPowerInPort {
        in power : PowerValue;
    }

    port def CmdOutPort {
        out cmd : HeatLevelCommand;
    }

    port def CmdInPort {
        in cmd : HeatLevelCommand;
    }

    port def TempOutPort {
        out temp : TemperatureValue;
    }

    port def TempInPort {
        in temp : TemperatureValue;
    }

    port def PowerCmdOutPort {
        out cmd : PowerCommand;
    }

    port def PowerCmdInPort {
        in cmd : PowerCommand;
    }

    port def DisplayOutPort {
        out temp : TemperatureValue;
    }

    port def DisplayInPort {
        in temp : TemperatureValue;
    }

    port def ShutdownOutPort {
        out signal : ShutdownSignal;
    }

    port def ShutdownInPort {
        in signal : ShutdownSignal;
    }

    action def ConvertACtoDC {
        out power : PowerValue;
    }

    action def SelectHeatLevel {
        out cmd : HeatLevelCommand;
    }

    action def DisplayTemperature {
        in temp : TemperatureValue;
    }

    action def SenseTemperature {
        out temp : TemperatureValue;
    }

    action def ApplyHeat {
        in cmd : PowerCommand;
    }

    action def RegulateTemperature {
        in level : HeatLevel;
        in temp : TemperatureValue;
        out cmd : PowerCommand;
    }

    action def CheckSafety {
        in temp : TemperatureValue;
        out signal : ShutdownSignal;
    }

    part def PowerSupply {
        port acInput : ACInputPort;
        port dcOutput : DCPowerPort;
        perform action convert : ConvertACtoDC;
    }

    part def UserInterface {
        port cmdOut : CmdOutPort;
        port displayIn : DisplayInPort;
        attribute selectedLevel : HeatLevel;
        perform action selectLevel : SelectHeatLevel;
        perform action displayTemp : DisplayTemperature;
    }

    part def TemperatureSensor {
        port toController : TempOutPort;
        port toSafety : TempOutPort;
        perform action sense : SenseTemperature;
    }

    part def HeatingElement {
        port powerIn : PowerCmdInPort;
        attribute resistance : ResistanceValue;
        perform action applyHeat : ApplyHeat;
    }

    part def FabricCover {
        attribute thickness : LengthValue;
    }

    part def SafetyCircuit {
        port tempIn : TempInPort;
        port shutdownOut : ShutdownOutPort;
        attribute maxSafeTemp : TemperatureValue = 333 [K];
        attribute autoShutoffDuration : DurationValue = 60 [min];
        perform action checkSafety : CheckSafety;

        exhibit state safetyStates {
            entry; then monitoring;
            state monitoring;
            accept when tempIn.temp > maxSafeTemp
                do send new ShutdownSignal() via shutdownOut
                then tripped;
            accept after 60 [min]
                do send new ShutdownSignal() via shutdownOut
                then tripped;
            state tripped;
        }
    }

    part def ControllerUnit {
        port cmdIn : CmdInPort;
        port tempIn : TempInPort;
        port safetyIn : ShutdownInPort;
        port powerOut : PowerCmdOutPort;
        port displayOut : DisplayOutPort;
        port supplyIn : DCPowerInPort;
        attribute desiredLevel : HeatLevel;
        attribute currentTemp : TemperatureValue;
        attribute targetTemp : TemperatureValue;
        attribute tempTolerance : TemperatureValue = 1 [K];
        perform action regulate : RegulateTemperature;
    }

    part def HeatingPad {
        port acInput : ACInputPort;

        attribute desiredLevel : HeatLevel;
        attribute currentTemp : TemperatureValue;
        attribute targetTemp : TemperatureValue;
        attribute tempTolerance : TemperatureValue = 1 [K];
        attribute maxSafeTemp : TemperatureValue = 333 [K];

        part powerSupply : PowerSupply;
        part userInterface : UserInterface;
        part controller : ControllerUnit;
        part tempSensor : TemperatureSensor;
        part heatingElement : HeatingElement;
        part fabricCover : FabricCover;
        part safetyCircuit : SafetyCircuit;

        perform action sense : SenseTemperature;

        connect acInput to powerSupply.acInput;
        connect powerSupply.dcOutput to controller.supplyIn;
        connect userInterface.cmdOut to controller.cmdIn;
        connect tempSensor.toController to controller.tempIn;
        connect tempSensor.toSafety to safetyCircuit.tempIn;
        connect controller.powerOut to heatingElement.powerIn;
        connect controller.displayOut to userInterface.displayIn;
        connect safetyCircuit.shutdownOut to controller.safetyIn;

        exhibit state heatingPadStates {
            entry; then off;

            do sense;

            state off;

            transition off_to_heating_low
                first off
                accept cmd : HeatLevelCommand via controller.cmdIn
                    if cmd.level == HeatLevel::low
                do assign targetTemp := 313 [K]
                then heating;

            transition off_to_heating_medium
                first off
                accept cmd : HeatLevelCommand via controller.cmdIn
                    if cmd.level == HeatLevel::medium
                do assign targetTemp := 323 [K]
                then heating;

            transition off_to_heating_high
                first off
                accept cmd : HeatLevelCommand via controller.cmdIn
                    if cmd.level == HeatLevel::high
                do assign targetTemp := 328 [K]
                then heating;

            state heating;

            transition heating_to_maintaining
                first heating
                accept when sense.temp >= targetTemp - tempTolerance
                    then maintaining;

            transition heating_to_off
                first heating
                accept cmd : HeatLevelCommand via controller.cmdIn
                    if cmd.level == HeatLevel::off
                then off;

            transition heating_shutdown
                first heating
                accept signal : ShutdownSignal via controller.safetyIn
                    then off;

            state maintaining;

            transition maintaining_to_heating
                first maintaining
                accept when sense.temp < targetTemp - tempTolerance
                    then heating;

            transition maintaining_to_cooling
                first maintaining
                accept when sense.temp > targetTemp + tempTolerance
                    then cooling;

            transition maintaining_to_off
                first maintaining
                accept cmd : HeatLevelCommand via controller.cmdIn
                    if cmd.level == HeatLevel::off
                then off;

            transition maintaining_shutdown
                first maintaining
                accept signal : ShutdownSignal via controller.safetyIn
                    then off;

            state cooling;

            transition cooling_to_maintaining
                first cooling
                accept when sense.temp <= targetTemp + tempTolerance
                    then maintaining;

            transition cooling_to_off
                first cooling
                accept cmd : HeatLevelCommand via controller.cmdIn
                    if cmd.level == HeatLevel::off
                then off;

            transition cooling_shutdown
                first cooling
                accept signal : ShutdownSignal via controller.safetyIn
                    then off;
        }
    }

    requirement def SafetyRequirements {
        doc /* The heating pad shall include safety mechanisms to prevent overheating. */
        subject pad : HeatingPad;
        requirement MaxTempLimit {
            doc /* The heating pad shall automatically shut down if the pad temperature exceeds 60 degrees C. */
            subject p : HeatingPad;
            constraint { p.maxSafeTemp <= 333 [K] }
        }
        requirement AutoShutoff {
            doc /* The heating pad shall automatically turn off after 60 minutes of continuous use. */
            subject p : HeatingPad;
            constraint { p.safetyCircuit.autoShutoffDuration <= 60 [min] }
        }
    }

    requirement def PerformanceRequirements {
        doc /* The heating pad shall maintain temperature within the specified tolerance. */
        subject pad : HeatingPad;
        requirement TempTolerance {
            doc /* The heating pad shall maintain the pad temperature within plus or minus 1 degree C of the target. */
            subject p : HeatingPad;
            constraint { p.currentTemp <= p.targetTemp + 1 [K] and p.currentTemp >= p.targetTemp - 1 [K] }
        }
    }

    part heatingPad : HeatingPad {
        attribute desiredLevel : HeatLevel = HeatLevel::medium;
        attribute targetTemp : TemperatureValue = 323 [K];
        attribute maxSafeTemp : TemperatureValue = 333 [K];
    }

    requirement safetyReqs : SafetyRequirements {
        subject pad = heatingPad;
    }

    requirement perfReqs : PerformanceRequirements {
        subject pad = heatingPad;
    }
}
