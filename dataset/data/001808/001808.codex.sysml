package MachinePrimaryFunctionModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Percent : Real {
        unit = "%";
    }

    attribute def RotationSpeed : Real {
        unit = "rpm";
    }

    attribute def ThroughputRate : Real {
        unit = "part/min";
    }

    attribute def Availability : Real {
        unit = "%";
    }

    attribute def TemperatureCelsius : Real {
        unit = "degC";
    }

    item def RawMaterial {
        attribute mass : MassValue;
        attribute materialGrade : String;
    }

    item def ProcessedProduct {
        attribute mass : MassValue;
        attribute qualityScore : Percent;
        attribute serialNumber : String;
    }

    item def ElectricalPower {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
        attribute frequency : FrequencyValue;
    }

    item def ControlCommand {
        attribute commandId : String;
        attribute requestedMode : MachineModeKind;
    }

    item def MachineStatus {
        attribute currentMode : MachineModeKind;
        attribute health : Percent;
        attribute outputRate : ThroughputRate;
        attribute faultCode : String;
    }

    enum def MachineModeKind {
        enum idle;
        enum starting;
        enum processing;
        enum paused;
        enum stopping;
        enum faulted;
        enum maintenance;
    }

    port def MaterialInputPort {
        in item material : RawMaterial;
    }

    port def ProductOutputPort {
        out item product : ProcessedProduct;
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    port def CommandInputPort {
        in item command : ControlCommand;
    }

    port def StatusOutputPort {
        out item status : MachineStatus;
    }

    part def Machine {
        attribute ratedPower : PowerValue;
        attribute nominalThroughput : ThroughputRate;
        attribute operatingTemperature : TemperatureCelsius;
        attribute availabilityTarget : Availability;

        port materialIn : MaterialInputPort;
        port productOut : ProductOutputPort;
        port powerIn : PowerInputPort;
        port commandIn : CommandInputPort;
        port statusOut : StatusOutputPort;

        action startMachine {
            in command : ControlCommand;
            out accepted : Boolean;
        }

        action processMaterial {
            in material : RawMaterial;
            out product : ProcessedProduct;
        }

        action stopMachine {
            out stopped : Boolean;
        }

        state machineState : MachineOperationalState;
    }

    state def MachineOperationalState {
        entry action initializeStatus;

        state idle;
        state starting;
        state processing;
        state paused;
        state stopping;
        state faulted;
        state maintenance;

        transition initial then idle;

        transition idle_to_starting
            first idle
            accept ControlCommand
            if command.requestedMode == MachineModeKind::processing
            then starting;

        transition starting_to_processing
            first starting
            after 5 [s]
            then processing;

        transition processing_to_paused
            first processing
            accept ControlCommand
            if command.requestedMode == MachineModeKind::paused
            then paused;

        transition paused_to_processing
            first paused
            accept ControlCommand
            if command.requestedMode == MachineModeKind::processing
            then processing;

        transition processing_to_stopping
            first processing
            accept ControlCommand
            if command.requestedMode == MachineModeKind::idle
            then stopping;

        transition stopping_to_idle
            first stopping
            after 3 [s]
            then idle;

        transition any_to_faulted
            first idle, starting, processing, paused, stopping
            accept MachineFaultDetected
            then faulted;

        transition faulted_to_maintenance
            first faulted
            accept ControlCommand
            if command.requestedMode == MachineModeKind::maintenance
            then maintenance;

        transition maintenance_to_idle
            first maintenance
            accept ControlCommand
            if command.requestedMode == MachineModeKind::idle
            then idle;
    }

    item def MachineFaultDetected {
        attribute faultCode : String;
        attribute severity : Integer;
    }

    part def OperatorPanel {
        port commandOut : CommandInputPort;
        port statusIn : StatusOutputPort;
    }

    part def PowerSupply {
        attribute nominalVoltage : VoltageValue = 480 [V];
        attribute nominalFrequency : FrequencyValue = 60 [Hz];
        port powerOut : PowerInputPort;
    }

    part def MaterialFeeder {
        attribute feedRate : ThroughputRate;
        port materialOut : MaterialInputPort;
    }

    part def ProductReceiver {
        attribute storageCapacity : Integer;
        port productIn : ProductOutputPort;
    }

    part def MachineBasedSystem {
        attribute systemName : String = "General Purpose Production Machine";
        attribute primaryFunction : String =
            "Convert incoming raw material into processed product under commanded operating modes while reporting machine status.";

        part machine : Machine {
            attribute ratedPower = 25 [kW];
            attribute nominalThroughput = 30 [part/min];
            attribute operatingTemperature = 45 [degC];
            attribute availabilityTarget = 98 [%];
        }

        part powerSupply : PowerSupply;
        part feeder : MaterialFeeder {
            attribute feedRate = 30 [part/min];
        }
        part receiver : ProductReceiver {
            attribute storageCapacity = 500;
        }
        part operatorPanel : OperatorPanel;

        connect powerSupply.powerOut to machine.powerIn;
        connect feeder.materialOut to machine.materialIn;
        connect machine.productOut to receiver.productIn;
        connect operatorPanel.commandOut to machine.commandIn;
        connect machine.statusOut to operatorPanel.statusIn;

        action performPrimaryFunction {
            in rawMaterial : RawMaterial;
            in command : ControlCommand;
            out processedProduct : ProcessedProduct;

            first start : machine.startMachine {
                in command = performPrimaryFunction.command;
            }

            then transform : machine.processMaterial {
                in material = performPrimaryFunction.rawMaterial;
                out product = performPrimaryFunction.processedProduct;
            }

            then stop : machine.stopMachine;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject system : MachineBasedSystem;

        require constraint {
            system.primaryFunction ==
            "Convert incoming raw material into processed product under commanded operating modes while reporting machine status."
        }
    }

    requirement def ThroughputRequirement {
        subject machine : Machine;

        require constraint {
            machine.nominalThroughput >= 30 [part/min]
        }
    }

    requirement def PowerRequirement {
        subject machine : Machine;

        require constraint {
            machine.ratedPower <= 25 [kW]
        }
    }

    requirement def AvailabilityRequirement {
        subject machine : Machine;

        require constraint {
            machine.availabilityTarget >= 98 [%]
        }
    }

    requirement def StatusReportingRequirement {
        subject system : MachineBasedSystem;

        require constraint {
            system.machine.statusOut.status.health >= 0 [%] and
            system.machine.statusOut.status.health <= 100 [%]
        }
    }

    requirement def SafeModeRequirement {
        subject machine : Machine;

        require constraint {
            machine.machineState == MachineModeKind::faulted implies
            machine.statusOut.status.outputRate == 0 [part/min]
        }
    }

    satisfy PrimaryFunctionRequirement by MachineBasedSystem;
    satisfy ThroughputRequirement by MachineBasedSystem::machine;
    satisfy PowerRequirement by MachineBasedSystem::machine;
    satisfy AvailabilityRequirement by MachineBasedSystem::machine;
    satisfy StatusReportingRequirement by MachineBasedSystem;
    satisfy SafeModeRequirement by MachineBasedSystem::machine;

    part productionMachineSystem : MachineBasedSystem;

}