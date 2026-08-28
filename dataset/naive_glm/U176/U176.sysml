package BubbleOxygenatorSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ---- Value Types with Units ----
    value type BloodFlowRate specializes Real {
    }
    attribute unit: String = "L/min";

    value type Temperature specializes Real {
    }
    attribute unit: String = "degC";

    value type OxygenSaturation specializes Real {
    }
    attribute unit: String = "%";

    value type PartialPressure specializes Real {
    }
    attribute unit: String = "mmHg";

    value type OxygenFlowRate specializes Real {
    }
    attribute unit: String = "L/min";

    value type GasBubbleDensity specializes Real {
    }
    attribute unit: String = "bubbles/mL";

    value type Power specializes Real {
    }
    attribute unit: String = "W";

    // ---- Item Types ----
    item def VenousBlood {
    attribute pO2: PartialPressure;
    attribute pCO2: PartialPressure;
    attribute sO2: OxygenSaturation;
    attribute temp: Temperature;
    attribute flowRate: BloodFlowRate;
    }

    item def OxygenGas {
    attribute flowRate: OxygenFlowRate;
    attribute purity: Real; // fraction
    }

    item def OxygenatedBloodWithBubbles {
    attribute pO2: PartialPressure;
    attribute pCO2: PartialPressure;
    attribute sO2: OxygenSaturation;
    attribute temp: Temperature;
    attribute bubbleDensity: GasBubbleDensity;
    }

    item def ArterialBlood {
    attribute pO2: PartialPressure;
    attribute pCO2: PartialPressure;
    attribute sO2: OxygenSaturation;
    attribute temp: Temperature;
    attribute flowRate: BloodFlowRate;
    }

    item def ExhaustGas {
    attribute pCO2: PartialPressure;
    attribute pO2: PartialPressure;
    attribute flowRate: OxygenFlowRate;
    }

    // ---- Port Definitions ----
    port def VenousBloodInPort {
    out item venousBlood: VenousBlood;
    }

    port def OxygenInPort {
    out item oxygen: OxygenGas;
    }

    port def BloodWithBubblesPort {
    out item bloodBubbles: OxygenatedBloodWithBubbles;
    }

    port def ArterialBloodOutPort {
    out item arterialBlood: ArterialBlood;
    }

    port def ExhaustGasPort {
    out item exhaust: ExhaustGas;
    }

    port def BloodFlowPort {
    out item blood: VenousBlood;
    }

    port def ControlSignalPort {
    out item setpoint: Real;
    in item measurement: Real;
    }

    // ---- Requirements ----
    requirement def SafeGasExchangeRequirement {
    subject oxygenator: BubbleOxygenatorSystem;
    objective {
    doc /* The system shall raise venous blood oxygen saturation to at least 95% and reduce pCO2 to below 40 mmHg. */
    }
    require oxygenator.outgoingArterialBlood.sO2 >= 95.0;
    require oxygenator.outgoingArterialBlood.pCO2 < 40.0;
    }

    requirement def BubbleRemovalRequirement {
    subject defoamer: DefoamingUnit;
    objective {
    doc /* The defoaming unit shall remove all gas bubbles from oxygenated blood before return to patient. */
    }
    require defoamer.outputBlood.bubbleDensity == 0.0;
    }

    requirement def TemperatureControlRequirement {
    subject tempUnit: TemperatureControlUnit;
    objective {
    doc /* Blood temperature shall be maintained between 34 and 37 degrees C. */
    }
    require tempUnit.controlledBloodTemp >= 34.0;
    require tempUnit.controlledBloodTemp <= 37.0;
    }

    requirement def FlowRegulationRequirement {
    subject flowReg: FlowRegulator;
    objective {
    doc /* Blood flow rate shall be maintained between 2 and 6 L/min. */
    }
    require flowReg.regulatedFlowRate >= 2.0;
    require flowReg.regulatedFlowRate <= 6.0;
    }

    requirement def MonitoringRequirement {
    subject monitor: OxygenationMonitor;
    objective {
    doc /* The monitor shall continuously measure pO2, pCO2, and sO2 of outgoing arterial blood. */
    }
    require monitor.measuredSO2 >= 95.0;
    require monitor.measuredPCO2 < 40.0;
    }

    // ---- Part Definitions ----

    part def BubbleGenerationModule {
    port oxygenIn: OxygenInPort;
    port bubbleOut: BloodWithBubblesPort;
    attribute bubbleSize: Real; // micrometers
    attribute generationRate: OxygenFlowRate;

    action GenerateBubbles {
    in oxygen: OxygenGas;
    out bloodBubbles: OxygenatedBloodWithBubbles;
    }
    }

    part def OxygenationColumn {
    port venousIn: VenousBloodInPort;
    port bubbleIn: BloodWithBubblesPort;
    port bloodOut: BloodWithBubblesPort;
    port exhaustOut: ExhaustGasPort;
    attribute columnVolume: Real; // mL
    attribute contactSurfaceArea: Real; // cm^2

    action PerformGasExchange {
    in venousBlood: VenousBlood;
    in oxygenBubbles: OxygenatedBloodWithBubbles;
    out oxygenatedBlood: OxygenatedBloodWithBubbles;
    out exhaust: ExhaustGas;
    }
    }

    part def DefoamingUnit {
    port bloodIn: BloodWithBubblesPort;
    port bloodOut: ArterialBloodOutPort;
    port exhaustOut: ExhaustGasPort;
    attribute filterArea: Real; // cm^2
    attribute antifoamCoating: String;

    action DefoamBlood {
    in bloodBubbles: OxygenatedBloodWithBubbles;
    out arterialBlood: ArterialBlood;
    out exhaust: ExhaustGas;
    }
    }

    part def TemperatureControlUnit {
    port controlPort: ControlSignalPort;
    attribute targetTemp: Temperature;
    attribute currentTemp: Temperature;
    attribute heatingPower: Power;
    attribute coolingPower: Power;

    action RegulateTemperature {
    in currentTemperature: Temperature;
    in targetTemperature: Temperature;
    out heatingOutput: Power;
    out coolingOutput: Power;
    }

    state TemperatureControlStateMachine {
    initial;
    state Monitoring;
    state Heating {
    entry { send heatingPower to controlPort; }
    }
    state Cooling {
    entry { send coolingPower to controlPort; }
    }
    state Stable;

    transition from initial to Monitoring;
    transition from Monitoring to Heating
    when currentTemp < targetTemp - 0.5;
    transition from Monitoring to Cooling
    when currentTemp > targetTemp + 0.5;
    transition from Monitoring to Stable
    when currentTemp >= targetTemp - 0.5 && currentTemp <= targetTemp + 0.5;
    transition from Heating to Monitoring
    when currentTemp >= targetTemp - 0.5;
    transition from Cooling to Monitoring
    when currentTemp <= targetTemp + 0.5;
    transition from Stable to Monitoring
    when currentTemp < targetTemp - 0.5 || currentTemp > targetTemp + 0.5;
    }
    }

    part def FlowRegulator {
    port bloodIn: VenousBloodInPort;
    port bloodOut: BloodFlowPort;
    port controlPort: ControlSignalPort;
    attribute regulatedFlowRate: BloodFlowRate;
    attribute targetFlowRate: BloodFlowRate;

    action RegulateFlow {
    in incomingBlood: VenousBlood;
    in target: BloodFlowRate;
    out regulatedBlood: VenousBlood;
    }
    }

    part def OxygenationMonitor {
    port bloodIn: ArterialBloodOutPort;
    port controlPort: ControlSignalPort;
    attribute measuredSO2: OxygenSaturation;
    attribute measuredPO2: PartialPressure;
    attribute measuredPCO2: PartialPressure;
    attribute alarmActive: Boolean;

    action SampleBlood {
    in arterialBlood: ArterialBlood;
    out sO2: OxygenSaturation;
    out pO2: PartialPressure;
    out pCO2: PartialPressure;
    }

    action RaiseAlarm {
    when measuredSO2 < 90.0 || measuredPCO2 > 45.0;
    }
    }

    // ---- Top-level System ----
    part def BubbleOxygenatorSystem {
    port venousBloodIn: VenousBloodInPort;
    port oxygenIn: OxygenInPort;
    port arterialBloodOut: ArterialBloodOutPort;
    port exhaustOut: ExhaustGasPort;
    port monitorControl: ControlSignalPort;

    attribute outgoingArterialBlood: ArterialBlood;

    part flowRegulator: FlowRegulator {
    attribute regulatedFlowRate: BloodFlowRate = 4.0;
    }

    part bubbleGenerator: BubbleGenerationModule {
    attribute bubbleSize: Real = 50.0;
    attribute generationRate: OxygenFlowRate = 3.0;
    }

    part oxygenationColumn: OxygenationColumn {
    attribute columnVolume: Real = 500.0;
    attribute contactSurfaceArea: Real = 20000.0;
    }

    part defoamingUnit: DefoamingUnit {
    attribute filterArea: Real = 1500.0;
    attribute antifoamCoating: String = "SiliconeAntifoam";
    }

    part temperatureControlUnit: TemperatureControlUnit {
    attribute targetTemp: Temperature = 37.0;
    attribute heatingPower: Power = 50.0;
    attribute coolingPower: Power = 40.0;
    }

    part oxygenationMonitor: OxygenationMonitor {
    attribute alarmActive: Boolean = false;
    }

    // Connections
    connection venousBloodIn to flowRegulator.bloodIn;
    connection flowRegulator.bloodOut to oxygenationColumn.venousIn;
    connection oxygenIn to bubbleGenerator.oxygenIn;
    connection bubbleGenerator.bubbleOut to oxygenationColumn.bubbleIn;
    connection oxygenationColumn.bloodOut to defoamingUnit.bloodIn;
    connection oxygenationColumn.exhaustOut to exhaustOut;
    connection defoamingUnit.bloodOut to arterialBloodOut;
    connection defoamingUnit.exhaustOut to exhaustOut;
    connection arterialBloodOut to oxygenationMonitor.bloodIn;
    connection oxygenationMonitor.controlPort to monitorControl;
    connection temperatureControlUnit.controlPort to monitorControl;

    // Requirements satisfaction
    satisfy SafeGasExchangeRequirement by self;
    satisfy BubbleRemovalRequirement by defoamingUnit;
    satisfy TemperatureControlRequirement by temperatureControlUnit;
    satisfy FlowRegulationRequirement by flowRegulator;
    satisfy MonitoringRequirement by oxygenationMonitor;

    // Overall system state machine
    state SystemOperationStateMachine {
    initial;
    state Standby;
    state Priming {
    entry { /* Prime tubing with saline */ }
    }
    state Operating {
    entry { /* Begin blood flow and oxygen delivery */ }
    }
    state AlarmCondition {
    entry { /* Trigger clinical alarm */ }
    }
    state Shutdown {
    entry { /* Safely stop flow and purge system */ }
    }
    state Final;

    transition from initial to Standby;
    transition from Standby to Priming
    when flowRegulator.regulatedFlowRate > 0.0;
    transition from Priming to Operating
    when oxygenationColumn.contactSurfaceArea > 0.0;
    transition from Operating to AlarmCondition
    when oxygenationMonitor.measuredSO2 < 90.0 || oxygenationMonitor.measuredPCO2 > 45.0;
    transition from AlarmCondition to Operating
    when oxygenationMonitor.measuredSO2 >= 95.0 && oxygenationMonitor.measuredPCO2 < 40.0;
    transition from Operating to Shutdown
    when flowRegulator.regulatedFlowRate == 0.0;
    transition from Shutdown to Final;
    }

    // Main operational action
    action OperateOxygenator {
    in venousBlood: VenousBlood;
    in oxygenSupply: OxygenGas;
    out arterialBlood: ArterialBlood;
    out exhaust: ExhaustGas;

    // Step 1: Regulate blood flow
    action regulateFlow: FlowRegulator::RegulateFlow {
    in incomingBlood = venousBlood;
    in target = flowRegulator.targetFlowRate;
    out regulatedBlood;
    }

    // Step 2: Generate oxygen bubbles
    action generateBubbles: BubbleGenerationModule::GenerateBubbles {
    in oxygen = oxygenSupply;
    out bloodBubbles;
    }

    // Step 3: Perform gas exchange in column
    action gasExchange: OxygenationColumn::PerformGasExchange {
    in venousBlood = regulateFlow.regulatedBlood;
    in oxygenBubbles = generateBubbles.bloodBubbles;
    out oxygenatedBlood;
    out exhaust;
    }

    // Step 4: Defoam the blood
    action defoam: DefoamingUnit::DefoamBlood {
    in bloodBubbles = gasExchange.oxygenatedBlood;
    out arterialBlood;
    out exhaust;
    }

    // Step 5: Monitor outgoing blood
    action monitor: OxygenationMonitor::SampleBlood {
    in arterialBlood = defoam.arterialBlood;
    out sO2;
    out pO2;
    out pCO2;
    }

    // Step 6: Regulate temperature throughout
    action regulateTemp: TemperatureControlUnit::RegulateTemperature {
    in currentTemperature = defoam.arterialBlood.temp;
    in targetTemperature = temperatureControlUnit.targetTemp;
    out heatingOutput;
    out coolingOutput;
    }
    }
    }
}
