package CryolatheSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def TemperatureValue :> Real;
    attribute def PressureValue :> Real;
    attribute def FlowRateValue :> Real;
    attribute def SpindleSpeedValue :> Real;
    attribute def FeedRateValue :> Real;
    attribute def ToleranceValue :> Real;
    
    enum def CryogenType {
        liquidNitrogen;
        liquidHelium;
        liquidArgon;
    }
    
    enum def MachiningMode {
        roughing;
        finishing;
        threading;
    }
    
    enum def SystemState {
        idle;
        precooling;
        machining;
        postWarmup;
        emergency;
    }
    
    item def Workpiece {
        attribute material : String;
        attribute currentTemperature : TemperatureValue;
        attribute initialDimensions : LengthValue[3];
        attribute finalDimensions : LengthValue[3];
        attribute surfaceFinish : ToleranceValue;
    }
    
    item def CryogenicFluid {
        attribute fluidType : CryogenType;
        attribute temperature : TemperatureValue;
        attribute flowRate : FlowRateValue;
        attribute pressure : PressureValue;
    }
    
    port def CryogenPort {
        inout fluid : CryogenicFluid;
    }
    
    port def PowerPort {
        attribute voltage : Real;
        attribute current : Real;
    }
    
    port def ControlSignalPort {
        attribute commandValue : Real;
    }
    
    port def WorkpiecePort {
        inout workpiece : Workpiece;
    }
    
    part def CryogenicDeliverySystem {
        attribute reservoirCapacity : VolumeValue;
        attribute currentLevel : VolumeValue;
        attribute deliveryPressure : PressureValue;
        attribute deliveryTemperature : TemperatureValue;
        
        port cryogenOutput : CryogenPort;
        port powerIn : PowerPort;
        port controlIn : ControlSignalPort;
        
        part reservoir {
            attribute capacity : VolumeValue = 200.0 [L];
            attribute level : VolumeValue;
            attribute internalPressure : PressureValue;
        }
        
        part cryoPump {
            attribute maxFlowRate : FlowRateValue = 0.01 [m^3/s];
            attribute efficiency : Real = 0.85;
        }
        
        part pressureRegulator {
            attribute setPoint : PressureValue = 300000.0 [Pa];
            attribute tolerance : PressureValue = 5000.0 [Pa];
        }
        
        part safetyReliefValve {
            attribute reliefPressure : PressureValue = 500000.0 [Pa];
        }
    }
    
    part def CryogenicChamber {
        attribute internalTemperature : TemperatureValue;
        attribute internalPressure : PressureValue;
        attribute targetTemperature : TemperatureValue;
        attribute chamberVolume : VolumeValue;
        
        port cryogenInlet : CryogenPort;
        port exhaustOutlet : CryogenPort;
        port workpieceInterface : WorkpiecePort;
        
        part thermalInsulation {
            attribute thickness : LengthValue = 0.05 [m];
            attribute thermalResistance : Real = 2.5;
        }
        
        part temperatureSensors[6] {
            attribute sensorId : Integer;
            out attribute reading : TemperatureValue;
            attribute accuracy : TemperatureValue = 0.5 [K];
        }
        
        part pressureSensor {
            out attribute reading : PressureValue;
            attribute accuracy : PressureValue = 1000.0 [Pa];
        }
        
        part viewPort {
            attribute diameter : LengthValue = 0.1 [m];
        }
    }
    
    part def SpindleAssembly {
        attribute currentSpeed : SpindleSpeedValue;
        attribute maxSpeed : SpindleSpeedValue;
        attribute torque : Real;
        attribute spindleTemperature : TemperatureValue;
        
        port powerIn : PowerPort;
        port controlIn : ControlSignalPort;
        port chuckInterface : WorkpiecePort;
        port coolantIn : CryogenPort;
        
        part spindleMotor {
            attribute ratedPower : PowerValue = 15000.0 [W];
            attribute maxTorque : Real = 200.0;
            attribute efficiency : Real = 0.92;
        }
        
        part chuck {
            attribute jawCount : Integer = 3;
            attribute maxGripDiameter : LengthValue = 0.3 [m];
            attribute grippingForce : Real = 50000.0;
        }
        
        part bearings[4] {
            attribute bearingType : String;
            attribute temperature : TemperatureValue;
        }
        
        part encoder {
            out attribute position : Real;
            out attribute velocity : SpindleSpeedValue;
            attribute resolution : Integer = 10000;
        }
    }
    
    part def ToolTurret {
        attribute currentPosition : Integer;
        attribute numberOfStations : Integer;
        attribute indexingTime : DurationValue;
        
        port powerIn : PowerPort;
        port controlIn : ControlSignalPort;
        
        part toolStations[8] {
            attribute stationNumber : Integer;
            attribute toolInstalled : Boolean;
        }
        
        part indexingMotor {
            attribute power : PowerValue = 500.0 [W];
            attribute positionAccuracy : Real = 0.001;
        }
    }
    
    part def CuttingToolAssembly {
        attribute feedRate : FeedRateValue;
        attribute depthOfCut : LengthValue;
        attribute toolPosition : LengthValue[3];
        attribute toolTemperature : TemperatureValue;
        
        port controlIn : ControlSignalPort;
        port coolantFlow : CryogenPort;
        
        part toolHolder {
            attribute holderType : String;
            attribute toolOffset : LengthValue[3];
        }
        
        part cuttingInsert {
            attribute insertMaterial : String;
            attribute insertGeometry : String;
            attribute wearLevel : Real;
        }
        
        part axisActuators[3] {
            attribute axisId : String;
            in attribute commandedPosition : LengthValue;
            out attribute actualPosition : LengthValue;
            attribute maxTravel : LengthValue = 0.5 [m];
            attribute resolution : LengthValue = 0.001 [mm];
        }
    }
    
    part def ControlSystem {
        attribute systemMode : SystemState;
        attribute programRunning : Boolean;
        attribute alarmStatus : String;
        
        port sensorInputs {
            in attribute chamberTemp : TemperatureValue;
            in attribute chamberPressure : PressureValue;
            in attribute spindleSpeed : SpindleSpeedValue;
            in attribute toolPositions : LengthValue[3];
            in attribute cryogenLevel : VolumeValue;
        }
        
        port actuatorOutputs {
            out attribute cryogenFlowCommand : FlowRateValue;
            out attribute spindleSpeedCommand : SpindleSpeedValue;
            out attribute toolFeedCommand : FeedRateValue;
            out attribute turretIndexCommand : Integer;
        }
        
        port operatorInterface {
            in attribute operatorCommands : String;
            out attribute statusDisplay : String;
        }
        
        part temperatureController {
            in attribute measuredTemp : TemperatureValue;
            in attribute setpointTemp : TemperatureValue;
            out attribute cryogenCommand : FlowRateValue;
            attribute kp : Real = 1.5;
            attribute ki : Real = 0.3;
            attribute kd : Real = 0.1;
        }
        
        part motionController {
            in attribute targetPositions : LengthValue[3];
            out attribute axisCommands : Real[3];
            attribute interpolationRate : Real = 1000.0;
        }
        
        part safetyMonitor {
            in attribute systemParameters : Real[*];
            out attribute emergencyStop : Boolean;
            attribute temperatureLimit : TemperatureValue = 400.0 [K];
            attribute pressureLimit : PressureValue = 600000.0 [Pa];
        }
        
        part programInterpreter {
            attribute currentLine : Integer;
            attribute programBuffer : String;
        }
    }
    
    part def SafetySystem {
        attribute emergencyStopActive : Boolean;
        attribute doorInterlockActive : Boolean;
        
        part emergencyStopCircuit {
            out attribute estopPressed : Boolean;
            attribute responseTime : DurationValue = 0.1 [s];
        }
        
        part doorInterlocks[3] {
            attribute doorId : Integer;
            out attribute doorClosed : Boolean;
        }
        
        part pressureReliefSystem {
            attribute activationPressure : PressureValue = 550000.0 [Pa];
        }
        
        part temperatureAlarms[4] {
            in attribute temperature : TemperatureValue;
            attribute alarmThreshold : TemperatureValue;
            out attribute alarmActive : Boolean;
        }
        
        part cryogenLeakDetector {
            out attribute leakDetected : Boolean;
            attribute sensitivity : Real = 0.01;
        }
    }
    
    action def InitializeSystem {
        first start;
        then action performSystemCheck {
            doc /* Verify all subsystems operational */
        }
        then action calibrateSensors {
            doc /* Calibrate temperature and pressure sensors */
        }
        then action primeDeliverySystem {
            doc /* Prime cryogenic delivery lines */
        }
        then done;
    }
    
    action def CoolWorkpiece {
        in workpiece : Workpiece;
        in targetTemp : TemperatureValue;
        out cooledWorkpiece : Workpiece;
        
        first start;
        then action openCryogenValve {
            doc /* Begin cryogen flow into chamber */
        }
        then merge monitorLoop;
        then action measureTemperature {
            out currentTemp : TemperatureValue;
        }
        then decide;
            if measureTemperature.currentTemp > targetTemp then adjustFlow;
            if measureTemperature.currentTemp <= targetTemp then stabilize;
        action adjustFlow {
            doc /* Adjust cryogen flow rate based on temperature */
        }
        then monitorLoop;
        action stabilize {
            doc /* Maintain stable cryogenic temperature */
        }
        then done;
    }
    
    action def ExecuteMachiningOperation {
        in workpiece : Workpiece;
        in machiningProgram : String;
        in mode : MachiningMode;
        out machinedWorkpiece : Workpiece;
        
        first start;
        then action loadProgram {
            doc /* Load NC program into controller */
        }
        then action positionTool {
            doc /* Move tool to start position */
        }
        then action accelerateSpindle {
            in targetSpeed : SpindleSpeedValue;
        }
        then action engageTool {
            doc /* Begin cutting operation */
        }
        then action executeCuttingPath {
            doc /* Follow programmed tool path */
        }
        then action retractTool {
            doc /* Withdraw tool from workpiece */
        }
        then action decelerateSpindle {
            doc /* Reduce spindle speed to zero */
        }
        then done;
    }
    
    action def WarmupWorkpiece {
        in workpiece : Workpiece;
        out warmedWorkpiece : Workpiece;
        
        first start;
        then action closeCryogenValve {
            doc /* Stop cryogen flow */
        }
        then action purgeExhaust {
            doc /* Vent residual cryogen */
        }
        then merge warmupLoop;
        then action monitorWarmup {
            out currentTemp : TemperatureValue;
        }
        then decide;
            if monitorWarmup.currentTemp < 273.0 then continueWarmup;
            if monitorWarmup.currentTemp >= 273.0 then complete;
        action continueWarmup {
            doc /* Allow gradual temperature rise */
        }
        then warmupLoop;
        action complete {
            doc /* Workpiece at safe handling temperature */
        }
        then done;
    }
    
    action def CompleteMachiningCycle {
        in rawWorkpiece : Workpiece;
        in ncProgram : String;
        in operatingMode : MachiningMode;
        out finishedWorkpiece : Workpiece;
        
        first start;
        then action initialize : InitializeSystem;
        then action loadWorkpiece {
            doc /* Secure workpiece in chuck */
        }
        then action precool : CoolWorkpiece {
            in workpiece = rawWorkpiece;
            in targetTemp = 77.0;
            out cooledWorkpiece : Workpiece;
        }
        then action machine : ExecuteMachiningOperation {
            in workpiece = precool.cooledWorkpiece;
            in machiningProgram = ncProgram;
            in mode = operatingMode;
            out machinedWorkpiece : Workpiece;
        }
        then action warmup : WarmupWorkpiece {
            in workpiece = machine.machinedWorkpiece;
            out warmedWorkpiece : Workpiece;
        }
        then action unloadWorkpiece {
            doc /* Remove finished workpiece from chuck */
        }
        then done;
    }
    
    state def CryolatheOperationalStates {
        in attribute systemMode : SystemState;
        
        entry; then idle;
        
        state idle;
        
        transition idle_to_precooling
            first idle
            accept StartCycleCommand
            then precooling;
        
        state precooling {
            do action coolChamber;
        }
        
        transition precooling_to_machining
            first precooling
            accept TargetTemperatureReached
            then machining;
        
        state machining {
            do action performCutting;
        }
        
        transition machining_to_postWarmup
            first machining
            accept ProgramComplete
            then postWarmup;
        
        state postWarmup {
            do action gradualWarmup;
        }
        
        transition postWarmup_to_idle
            first postWarmup
            accept AmbientTemperatureReached
            then idle;
        
        state emergency {
            do action emergencyShutdown;
        }
        
        transition any_to_emergency
            accept EmergencyStopActivated
            then emergency;
        
        transition emergency_to_idle
            first emergency
            accept SystemReset
            then idle;
    }
    
    part def Cryolathe;
    
    part cryolathe : Cryolathe {
        doc /* 
         * Cryogenic lathe system for ultra-precision machining of materials
         * at cryogenic temperatures. The system achieves superior dimensional
         * accuracy and surface finish by maintaining workpiece and cutting zone
         * at liquid nitrogen temperatures during machining operations.
         */
        
        attribute systemTemperature : TemperatureValue;
        attribute systemPressure : PressureValue;
        attribute operationalState : SystemState;
        attribute cycleCount : Integer;
        
        part cryoDelivery : CryogenicDeliverySystem {
            :>> reservoirCapacity = 200.0 [L];
            :>> currentLevel = 150.0 [L];
            :>> deliveryPressure = 300000.0 [Pa];
            :>> deliveryTemperature = 77.0 [K];
        }
        
        part chamber : CryogenicChamber {
            :>> targetTemperature = 77.0 [K];
            :>> chamberVolume = 0.5 [m^3];
        }
        
        part spindle : SpindleAssembly {
            :>> maxSpeed = 3000.0;
        }
        
        part turret : ToolTurret {
            :>> numberOfStations = 8;
            :>> indexingTime = 2.0 [s];
        }
        
        part toolAssembly : CuttingToolAssembly;
        
        part controller : ControlSystem {
            :>> systemMode = SystemState::idle;
            :>> programRunning = false;
        }
        
        part safety : SafetySystem {
            :>> emergencyStopActive = false;
            :>> doorInterlockActive = false;
        }
        
        connection cryogenSupply connect 
            cryoDelivery.cryogenOutput to chamber.cryogenInlet;
        
        connection spindleCooling connect
            cryoDelivery.cryogenOutput to spindle.coolantIn;
        
        connection toolCooling connect
            cryoDelivery.cryogenOutput to toolAssembly.coolantFlow;
        
        connection temperatureFeedback connect
            chamber.temperatureSensors[1] to controller.sensorInputs;
        
        connection pressureFeedback connect
            chamber.pressureSensor to controller.sensorInputs;
        
        connection spindleFeedback connect
            spindle.encoder to controller.sensorInputs;
        
        connection cryoControl connect
            controller.actuatorOutputs to cryoDelivery.controlIn;
        
        connection spindleControl connect
            controller.actuatorOutputs to spindle.controlIn;
        
        connection turretControl connect
            controller.actuatorOutputs to turret.controlIn;
        
        connection toolControl connect
            controller.actuatorOutputs to toolAssembly.controlIn;
        
        connection safetyInterlock connect
            safety.emergencyStopCircuit to controller.safetyMonitor;
        
        connection doorInterlock connect
            safety.doorInterlocks[1] to controller.safetyMonitor;
        
        perform action machiningCycle : CompleteMachiningCycle;
        
        exhibit state operatingStates : CryolatheOperationalStates {
            in systemMode = controller.systemMode;
        }
    }
    
    requirement <'REQ-CL-100'> primaryFunction {
        doc /* 
         * The Cryolathe system shall perform ultra-precision machining operations
         * on metallic and composite workpieces by maintaining the cutting zone
         * at cryogenic temperatures (77K nominal) to achieve enhanced material
         * removal characteristics, superior surface finish, and dimensional
         * accuracy beyond conventional machining capabilities.
         */
        subject system : Cryolathe;
    }
    
    requirement <'REQ-CL-101'> cryogenicTemperatureControl {
        doc /*
         * The system shall maintain the workpiece and cutting zone temperature
         * at 77K ± 3K during active machining operations.
         */
        subject chamber :>> cryolathe.chamber;
        assert constraint {
            chamber.internalTemperature >= 74.0 and
            chamber.internalTemperature <= 80.0
        }
    }
    
    requirement <'REQ-CL-102'> cryogenSupplyCapacity {
        doc /*
         * The cryogenic delivery system shall maintain sufficient liquid nitrogen
         * capacity for continuous operation of at least 6 hours at maximum flow rate.
         */
        subject delivery :>> cryolathe.cryoDelivery;
        assert constraint {
            delivery.currentLevel >= 0.20 * delivery.reservoirCapacity
        }
    }
    
    requirement <'REQ-CL-103'> machiningAccuracy {
        doc /*
         * The system shall achieve dimensional accuracy within ±0.002 mm
         * and surface finish better than 0.2 μm Ra on specified materials.
         */
        subject tooling :>> cryolathe.toolAssembly;
    }
    
    requirement <'REQ-CL-104'> spindlePerformance {
        doc /*
         * The spindle assembly shall operate at speeds up to 3000 RPM
         * while maintaining temperature stability within ±2K.
         */
        subject spindle :>> cryolathe.spindle;
        assert constraint {
            spindle.currentSpeed <= spindle.maxSpeed
        }
    }
    
    requirement <'REQ-CL-105'> safetyResponse {
        doc /*
         * The system shall execute complete emergency shutdown within 1.5 seconds
         * of emergency stop activation, including cryogen flow termination.
         */
        subject safetySystem :>> cryolathe.safety;
    }
    
    requirement <'REQ-CL-106'> thermalStability {
        doc /*
         * The chamber shall maintain thermal stability with temperature
         * variation less than 1K per minute during steady-state operation.
         */
        subject chamber :>> cryolathe.chamber;
    }
    
    satisfy primaryFunction by cryolathe;
    satisfy cryogenicTemperatureControl by cryolathe.chamber;
    satisfy cryogenSupplyCapacity by cryolathe.cryoDelivery;
    satisfy machiningAccuracy by cryolathe.toolAssembly;
    satisfy spindlePerformance by cryolathe.spindle;
    satisfy safetyResponse by cryolathe.safety;
    satisfy thermalStability by cryolathe.chamber;
}
