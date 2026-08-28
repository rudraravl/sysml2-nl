package 'Seed Counting Machine' {
    private import ScalarValues::*;
    private import ISQ::*;

    item def Seed;

    attribute def StartCommand;
    attribute def StopCommand;
    attribute def ResetCommand;
    attribute def SeedPulse;
    attribute def ErrorSignal;
    attribute def DisplayData {
        attribute currentCount : Integer;
        attribute status : String;
    }

    part def HopperFeeder {
        out port seedOut : Seed;
        in port feederControl : Boolean;
        action def DispenseSeeds { out seeds : Seed; }
        perform action dispense : DispenseSeeds;
    }

    part def ConveyorBelt {
        in port seedIn : Seed;
        out port seedOut : Seed;
        in port conveyorControl : Boolean;
        action def TransportSeeds { in seedsIn : Seed; out seedsOut : Seed; }
        perform action transport : TransportSeeds;
    }

    part def OpticalSensor {
        in port seedIn : Seed;
        out port seedOut : Seed;
        out port pulseOut : SeedPulse;
        action def DetectSeed { in seed : Seed; out pulse : SeedPulse; }
        perform action detect : DetectSeed;
    }

    action def IncrementCount;
    action def StopFeeder;
    action def StopConveyor;
    action def UpdateDisplay;
    action def AlertOperator;

    part def CountingController {
        in port pulseIn : SeedPulse;
        in port startIn : StartCommand;
        in port stopIn : StopCommand;
        in port resetIn : ResetCommand;
        in port faultIn : ErrorSignal;
        out port displayOut : DisplayData;
        out port feederControl : Boolean;
        out port conveyorControl : Boolean;

        attribute targetCount : Integer = 100;
        attribute currentCount : Integer = 0;

        exhibit state machine : ControllerStates;
    }

    part def DisplayUnit {
        in port displayIn : DisplayData;
        action def DisplayStatus { in status : DisplayData; }
        perform action display : DisplayStatus;
    }

    part def CollectionBin {
        in port seedIn : Seed;
        attribute capacity : Integer;
    }

    part def SeedCountingMachine {
        part hopperFeeder : HopperFeeder;
        part conveyorBelt : ConveyorBelt;
        part opticalSensor : OpticalSensor;
        part countingController : CountingController;
        part displayUnit : DisplayUnit;
        part collectionBin : CollectionBin;

        flow hopperToConveyor : Seed from hopperFeeder.seedOut to conveyorBelt.seedIn;
        flow conveyorToSensor : Seed from conveyorBelt.seedOut to opticalSensor.seedIn;
        flow sensorToBin : Seed from opticalSensor.seedOut to collectionBin.seedIn;
        flow sensorToController : SeedPulse from opticalSensor.pulseOut to countingController.pulseIn;
        flow controllerToDisplay : DisplayData from countingController.displayOut to displayUnit.displayIn;
        flow controllerToFeeder : Boolean from countingController.feederControl to hopperFeeder.feederControl;
        flow controllerToConveyor : Boolean from countingController.conveyorControl to conveyorBelt.conveyorControl;

        requirement def 'Counting Accuracy' {
            doc /* The machine shall count seeds with an error rate of no more than 0.1%. */
        }
        requirement def 'Batch Completion' {
            doc /* The machine shall stop feeding when the target count is reached and clear the conveyor before signaling completion. */
        }
        requirement def 'Fault Detection' {
            doc /* The machine shall detect faults and alert the operator. */
        }
    }

    state def ControllerStates {
        entry; then idle;
        state idle;
        accept StartCommand then ready;
        state ready;
        accept SeedPulse then counting;
        state counting;
        accept SeedPulse
            do IncrementCount
            then counting;
        accept SeedPulse
            if currentCount >= targetCount
            do StopFeeder
            then clearing;
        state clearing;
        accept after 5 [s] then complete;
        state complete;
        accept ResetCommand then idle;
        accept ErrorSignal then error;
        state error;
        accept ResetCommand then idle;
    }
}
