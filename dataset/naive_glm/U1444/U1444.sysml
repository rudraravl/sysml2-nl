package IndustrialProcessingMachine {

    import ScalarValues::*;

    // ===== Value Types =====
    value def Temperature :> Real { unit "K"; }
    value def MassFlowRate :> Real { unit "kg/s"; }
    value def VolumetricFlowRate :> Real { unit "L/s"; }
    value def Voltage :> Real { unit "V"; }
    value def Current :> Real { unit "A"; }
    value def Power :> Real { unit "W"; }
    value def RotationalSpeed :> Real { unit "rpm"; }
    value def Pressure :> Real { unit "Pa"; }
    value def Mass :> Real { unit "kg"; }
    value def Duration :> Real { unit "s"; }
    value def Percent :> Real { unit "%"; }
    value def Density :> Real { unit "kg/m3"; }

    // ===== Enumerations =====
    enum def ControlCommand {
        none;
        startUp;
        shutDown;
        emergencyStop;
        setSpeed;
        setFeedRate;
    }

    enum def MachineState {
        offline;
        startingUp;
        ready;
        processing;
        shuttingDown;
        coolingDown;
        fault;
    }

    enum def FaultType {
        none;
        overTemperature;
        powerFailure;
        coolantFailure;
        feederJam;
    }

    // ===== Item Types =====
    item def RawMaterial {
        attribute purity : Percent;
        attribute density : Density;
        attribute batchId : String;
    }

    item def RefinedProduct {
        attribute qualityGrade : Integer;
        attribute mass : Mass;
        attribute batchId : String;
    }

    item def CoolantFluid {
        attribute temperature : Temperature;
        attribute flowRate : VolumetricFlowRate;
        attribute type : String;
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute activePower : Power;
    }

    item def SensorFeedback {
        attribute coreTemperature : Temperature;
        attribute coreSpeed : RotationalSpeed;
        attribute powerConsumption : Power;
        attribute coolantPressure : Pressure;
        attribute coolantFlowRate : VolumetricFlowRate;
        attribute productLevel : Mass;
        attribute feederLoad : Mass;
        attribute faultType : FaultType;
    }

    // ===== Port Definitions =====
    port def MaterialOutPort {
        out material : RawMaterial;
        attribute flowRate : MassFlowRate;
    }

    port def MaterialInPort {
        in material : RawMaterial;
        attribute flowRate : MassFlowRate;
    }

    port def ProductOutPort {
        out product : RefinedProduct;
    }

    port def ProductInPort {
        in product : RefinedProduct;
    }

    port def CoolantOutPort {
        out coolant : CoolantFluid;
        attribute flowRate : VolumetricFlowRate;
    }

    port def CoolantInPort {
        in coolant : CoolantFluid;
        attribute flowRate : VolumetricFlowRate;
    }

    port def PowerOutPort {
        out power : ElectricalPower;
    }

    port def PowerInPort {
        in power : ElectricalPower;
    }

    port def ControlPort {
        in command : ControlCommand;
        out feedback : SensorFeedback;
    }

    // ===== Action Definitions =====
    action def WarmUp {
        in targetTemperature : Temperature;
        in currentTemperature : Temperature;
        out heaterActive : Boolean;
        out achievedTemperature : Temperature;
    }

    action def ProcessMaterial {
        in rawMaterial : RawMaterial;
        in operatingSpeed : RotationalSpeed;
        out refinedProduct : RefinedProduct;
        out heatGenerated : Temperature;
    }

    action def ControlledShutdown {
        in currentSpeed : RotationalSpeed;
        out finalSpeed : RotationalSpeed;
    }

    action def CoolDownAction {
        in currentTemperature : Temperature;
        in targetTemperature : Temperature;
        out achievedTemperature : Temperature;
        out coolingActive : Boolean;
    }

    action def EmergencyShutdownAction {
        in faultType : FaultType;
        out systemSafe : Boolean;
    }

    action def FeedMaterial {
        in feedRate : MassFlowRate;
        out material : RawMaterial;
    }

    action def SupplyPower {
        in demand : Power;
        out power : ElectricalPower;
    }

    action def CirculateCoolant {
        in flowRate : VolumetricFlowRate;
        out coolant : CoolantFluid;
        in returnCoolant : CoolantFluid;
    }

    action def CollectProduct {
        in product : RefinedProduct;
        out collectedMass : Mass;
    }

    action def MonitorSensors {
        in feedback : SensorFeedback;
        out processedFeedback : SensorFeedback;
    }

    action def AdjustParameters {
        in feedback : SensorFeedback;
        in targetSpeed : RotationalSpeed;
        in targetTemperature : Temperature;
        out speedCommand : RotationalSpeed;
        out coolantCommand : VolumetricFlowRate;
        out feedRateCommand : MassFlowRate;
    }

    action def ControlLoop {
        in feedback : SensorFeedback;
        out speedCommand : RotationalSpeed;
        out coolantCommand : VolumetricFlowRate;
        out feedRateCommand : MassFlowRate;
        loop {
            action monitor : MonitorSensors;
            action adjust : AdjustParameters;
            flow monitor.processedFeedback to adjust.feedback;
        }
    }

    // ===== Part Definitions =====
    part def ProcessingCore {
        port materialIn : MaterialInPort;
        port productOut : ProductOutPort;
        port coolantIn : CoolantInPort;
        port coolantOut : CoolantOutPort;
        port powerIn : PowerInPort;
        port control : ControlPort;

        attribute operatingTemperature : Temperature = 450.0;
        attribute maxTemperature : Temperature = 550.0;
        attribute currentTemperature : Temperature;
        attribute processingSpeed : RotationalSpeed;
        attribute maxSpeed : RotationalSpeed = 3000;
        attribute powerConsumption : Power;
        attribute transformationEfficiency : Percent = 92.0;
        attribute active : Boolean = false;

        action def Transform {
            in rawMaterial : RawMaterial;
            in speed : RotationalSpeed;
            out product : RefinedProduct;
            out heatGenerated : Temperature;
        }
    }

    part def MaterialFeeder {
        port materialOut : MaterialOutPort;
        port control : ControlPort;

        attribute feedRate : MassFlowRate;
        attribute maxFeedRate : MassFlowRate = 5.0;
        attribute hopperCapacity : Mass = 50.0;
        attribute currentLoad : Mass;
        attribute active : Boolean = false;
    }

    part def PowerSupplyUnit {
        port powerOut : PowerOutPort;
        port control : ControlPort;

        attribute outputVoltage : Voltage = 480.0;
        attribute maxOutputPower : Power = 50000.0;
        attribute currentOutput : Power;
        attribute efficiency : Percent = 94.0;
        attribute active : Boolean = false;
    }

    part def CoolingSystem {
        port coolantOut : CoolantOutPort;
        port coolantIn : CoolantInPort;
        port control : ControlPort;

        attribute coolantFlowRate : VolumetricFlowRate;
        attribute maxFlowRate : VolumetricFlowRate = 20.0;
        attribute coolantTemperature : Temperature = 293.15;
        attribute pumpPressure : Pressure;
        attribute maxPressure : Pressure = 300000.0;
        attribute radiatorFanSpeed : RotationalSpeed;
        attribute active : Boolean = false;
    }

    part def ProductCollector {
        port productIn : ProductInPort;
        port control : ControlPort;

        attribute capacity : Mass = 100.0;
        attribute currentFill : Mass;
        attribute fillLevel : Percent;
        attribute isFull : Boolean = false;
    }

    part def ControlSystem {
        port processingCoreControl : ~ControlPort;
        port feederControl : ~ControlPort;
        port powerControl : ~ControlPort;
        port coolingControl : ~ControlPort;
        port collectorControl : ~ControlPort;

        attribute targetSpeed : RotationalSpeed = 2500;
        attribute targetTemperature : Temperature = 450.0;
        attribute currentFeedback : SensorFeedback;
        attribute machineState : MachineState = MachineState::offline;
        attribute faultDetected : Boolean = false;
        attribute faultType : FaultType = FaultType::none;
        attribute controlLoopInterval : Duration = 0.1;
    }

    // ===== Connection Definitions =====
    connection def MaterialFlowConnection {
        end source : MaterialOutPort;
        end target : MaterialInPort;
        item : RawMaterial;
    }

    connection def ProductFlowConnection {
        end source : ProductOutPort;
        end target : ProductInPort;
        item : RefinedProduct;
    }

    connection def CoolantSupplyConnection {
        end source : CoolantOutPort;
        end target : CoolantInPort;
        item : CoolantFluid;
    }

    connection def CoolantReturnConnection {
        end source : CoolantOutPort;
        end target : CoolantInPort;
        item : CoolantFluid;
    }

    connection def PowerConnection {
        end source : PowerOutPort;
        end target : PowerInPort;
        item : ElectricalPower;
    }

    connection def ControlConnection {
        end source : ~ControlPort;
        end target : ControlPort;
    }

    // ===== State Machine Definition =====
    state def MachineLifecycle {
        state offline {
            entry;
            transition to startingUp
                when operatorCommand == ControlCommand::startUp;
        }

        state startingUp {
            entry;
            do warmUp : WarmUp;
            transition to ready
                when coreTemperature >= operatingTemperature;
        }

        state ready {
            entry;
            transition to processing
                when operatorCommand == ControlCommand::setSpeed;
        }

        state processing {
            entry;
            do processMaterial : ProcessMaterial;
            transition to shuttingDown
                when jobComplete == true;
            transition to fault
                when (coreTemperature > maxTemperature) or (powerFailure == true);
        }

        state shuttingDown {
            entry;
            do controlledShutdown : ControlledShutdown;
            transition to coolingDown;
        }

        state coolingDown {
            entry;
            do coolDown : CoolDownAction;
            transition to offline
                when coreTemperature <= ambientTemperature;
        }

        state fault {
            entry;
            do emergencyShutdown : EmergencyShutdownAction;
            transition to offline
                when systemSafe == true;
        }
    }

    // ===== Top-Level Machine =====
    part def IndustrialProcessingMachine {
        attribute operatingTemperature : Temperature = 450.0;
        attribute ambientTemperature : Temperature = 293.15;
        attribute maxTemperature : Temperature = 550.0;
        attribute coreTemperature : Temperature;
        attribute operatorCommand : ControlCommand = ControlCommand::none;
        attribute jobComplete : Boolean = false;
        attribute powerFailure : Boolean = false;
        attribute systemSafe : Boolean = false;
        attribute currentFaultType : FaultType = FaultType::none;
        attribute machineState : MachineState = MachineState::offline;

        part processingCore : ProcessingCore;
        part materialFeeder : MaterialFeeder;
        part powerSupply : PowerSupplyUnit;
        part coolingSystem : CoolingSystem;
        part productCollector : ProductCollector;
        part controlSystem : ControlSystem;

        bind coreTemperature = processingCore.currentTemperature;

        connection feederToCore : MaterialFlowConnection
            connect materialFeeder.materialOut to processingCore.materialIn;

        connection coreToCollector : ProductFlowConnection
            connect processingCore.productOut to productCollector.productIn;

        connection powerToCore : PowerConnection
            connect powerSupply.powerOut to processingCore.powerIn;

        connection coolingToCore : CoolantSupplyConnection
            connect coolingSystem.coolantOut to processingCore.coolantIn;

        connection coreToCooling : CoolantReturnConnection
            connect processingCore.coolantOut to coolingSystem.coolantIn;

        connection controlToCore : ControlConnection
            connect controlSystem.processingCoreControl to processingCore.control;

        connection controlToFeeder : ControlConnection
            connect controlSystem.feederControl to materialFeeder.control;

        connection controlToPower : ControlConnection
            connect controlSystem.powerControl to powerSupply.control;

        connection controlToCooling : ControlConnection
            connect controlSystem.coolingControl to coolingSystem.control;

        connection controlToCollector : ControlConnection
            connect controlSystem.collectorControl to productCollector.control;

        exhibit lifecycle : MachineLifecycle;
    }

    // ===== Requirements =====
    requirement def ContinuousProcessingRequirement {
        doc "The machine shall continuously transform a stream of raw material into a refined, high-quality product.";
        subject machine : IndustrialProcessingMachine;
    }

    requirement def StartupSequenceRequirement {
        doc "The machine shall perform a controlled startup sequence to warm up to its optimal operating temperature before entering the processing state.";
        subject machine : IndustrialProcessingMachine;
        attribute maxWarmUpTime : Duration = 300.0;
    }

    requirement def ProcessingStateRequirement {
        doc "The machine shall enter a processing state upon reaching optimal operating temperature and receiving operator commands to begin processing.";
        subject machine : IndustrialProcessingMachine;
    }

    requirement def ShutdownCooldownRequirement {
        doc "The machine shall undergo a managed shutdown and cooldown sequence to return to a safe, offline state after job completion.";
        subject machine : IndustrialProcessingMachine;
        attribute maxCooldownTime : Duration = 600.0;
    }

    requirement def EmergencyShutdownRequirement {
        doc "The control system shall trigger an emergency shutdown in case of a critical fault such as overheating or power failure.";
        subject machine : IndustrialProcessingMachine;
        attribute maxResponseTime : Duration = 1.0;
    }

    requirement def TemperatureControlRequirement {
        doc "The cooling system shall actively circulate coolant through the processing core to maintain a stable and safe operating temperature.";
        subject machine : IndustrialProcessingMachine;
        attribute maxOperatingTemp : Temperature = 550.0;
    }

    requirement def PowerSupplyRequirement {
        doc "The power supply unit shall provide the high-voltage electrical power needed for the transformation process.";
        subject machine : IndustrialProcessingMachine;
        attribute requiredVoltage : Voltage = 480.0;
        attribute requiredPower : Power = 50000.0;
    }

    requirement def MaterialFeedRequirement {
        doc "The material feeder shall automatically supply raw material to the processing core at a controlled rate.";
        subject machine : IndustrialProcessingMachine;
        attribute maxFeedRate : MassFlowRate = 5.0;
    }

    requirement def ProductCollectionRequirement {
        doc "The product collector shall gather finished product with a capacity to hold a specified amount before requiring emptying.";
        subject machine : IndustrialProcessingMachine;
        attribute collectorCapacity : Mass = 100.0;
    }

    requirement def ControlLoopRequirement {
        doc "The control system shall monitor vital signs including speed, temperature, and power consumption, and adjust operating parameters in a continuous control loop.";
        subject machine : IndustrialProcessingMachine;
        attribute loopInterval : Duration = 0.1;
    }

    requirement def SafetyRequirement {
        doc "The machine shall ensure safety and product quality through active cooling, controlled startup and shutdown, and emergency fault response.";
        subject machine : IndustrialProcessingMachine;
    }

    // ===== Satisfaction =====
    satisfy ContinuousProcessingRequirement by IndustrialProcessingMachine;
    satisfy StartupSequenceRequirement by IndustrialProcessingMachine;
    satisfy ProcessingStateRequirement by IndustrialProcessingMachine;
    satisfy ShutdownCooldownRequirement by IndustrialProcessingMachine;
    satisfy EmergencyShutdownRequirement by IndustrialProcessingMachine;
    satisfy TemperatureControlRequirement by IndustrialProcessingMachine;
    satisfy PowerSupplyRequirement by IndustrialProcessingMachine;
    satisfy MaterialFeedRequirement by IndustrialProcessingMachine;
    satisfy ProductCollectionRequirement by IndustrialProcessingMachine;
    satisfy ControlLoopRequirement by IndustrialProcessingMachine;
    satisfy SafetyRequirement by IndustrialProcessingMachine;
}
