package CryogenicBolometerSystem {
import ScalarValues::*;
import SI::*;
import ISQ::*;

// ===== Value Types =====
value type Temperature :> Real { unit K; }
value type RadiantPower :> Real { unit W; }
value type Voltage :> Real { unit V; }
value type Resistance :> Real { unit 'Ω'; }
value type Current :> Real { unit A; }
value type AmplifierGain :> Real { unit '1'; }
value type ThermalConductance :> Real { unit 'W/K'; }
value type HeatCapacity :> Real { unit 'J/K'; }
value type Frequency :> Real { unit Hz; }
value type Dimensionless :> Real { unit '1'; }
value type Area :> Real { unit 'm²'; }
value type TimeValue :> Real { unit 's'; }

// ===== Item Definitions =====
item def ElectromagneticRadiation {
attribute power : RadiantPower;
attribute frequency : Frequency;
}

item def HeatFlow {
attribute rate : RadiantPower;
}

item def ElectricalSignal {
attribute voltage : Voltage;
attribute current : Current;
}

item def MeasurementData {
attribute incidentPower : RadiantPower;
attribute timestamp : String;
attribute valid : Boolean;
attribute mode : String;
}

// ===== Port Definitions =====
port def OpticalPort {
in item radiation : ElectromagneticRadiation;
}

port def ThermalSourcePort {
out item heat : HeatFlow;
attribute temperature : Temperature;
}

port def ThermalSinkPort {
in item heat : HeatFlow;
attribute temperature : Temperature;
}

port def ElectricalInPort {
in item signal : ElectricalSignal;
}

port def ElectricalOutPort {
out item signal : ElectricalSignal;
}

port def DataOutPort {
out item data : MeasurementData;
}

port def CommandInPort {
in attribute command : String;
}

// ===== Calculation Definitions =====
calc def ThermistorResistanceCalc {
in baseResistance : Resistance;
in temperatureCoefficient : Real;
in temperatureChange : Temperature;
out resistance : Resistance;
}

calc def IncidentPowerCalc {
in amplifiedVoltage : Voltage;
in amplifierGain : AmplifierGain;
in biasVoltage : Voltage;
in calibrationFactor : Dimensionless;
out incidentPower : RadiantPower;
}

// ===== Part Definitions =====

part def AbsorberElement {
port opticalIn : OpticalPort;
port thermalOut : ThermalSourcePort;

attribute absorptionEfficiency : Dimensionless = 0.95;
attribute heatCapacity : HeatCapacity = 1.0e-9;
attribute activeArea : Area = 1.0e-6;
attribute currentTemperature : Temperature = 4.2;

action def AbsorbRadiation {
in radiation : ElectromagneticRadiation;
out heat : HeatFlow;
}

action absorb : AbsorbRadiation {}
}

part def ThermistorSensor {
port thermalIn : ThermalSinkPort;
port thermalIsolationOut : ThermalSourcePort;
port biasDriveIn : ElectricalInPort;
port electricalOut : ElectricalOutPort;

attribute baseResistance : Resistance = 10.0e6;
attribute baseTemperature : Temperature = 4.2;
attribute temperatureCoefficient : Real = -0.05;
attribute currentTemperature : Temperature = 4.2;
attribute currentResistance : Resistance = 10.0e6;
attribute thermalTimeConstant : TimeValue = 1.0;

action def TransduceThermalToElectrical {
in heat : HeatFlow;
out signal : ElectricalSignal;
}

action transduce : TransduceThermalToElectrical {}

calc resistanceCalc : ThermistorResistanceCalc {}
}

part def CryogenicHeatSink {
port thermalIn : ThermalSinkPort;

attribute sinkTemperature : Temperature = 4.2;
attribute coolingCapacity : RadiantPower = 0.1;
attribute coolant : String = "LiquidHelium";
}

part def ThermalIsolationLink {
port sensorSide : ThermalSinkPort;
port sinkSide : ThermalSourcePort;

attribute thermalConductance : ThermalConductance = 1.0e-9;
attribute material : String = "Kevlar";
}

part def BiasCircuit {
port biasDriveOut : ElectricalOutPort;
port senseInput : ElectricalInPort;
port senseOutput : ElectricalOutPort;

attribute biasVoltage : Voltage = 1.0e-3;
attribute stability : Dimensionless = 1.0e-6;
attribute referenceResistance : Resistance = 100.0e3;

action def ApplyBias {
in thermistorSignal : ElectricalSignal;
out biasedSignal : ElectricalSignal;
}

action bias : ApplyBias {}
}

part def ReadoutAmplifier {
port ampInput : ElectricalInPort;
port ampOutput : ElectricalOutPort;

attribute gain : AmplifierGain = 10000;
attribute bandwidth : Frequency = 1000;
attribute inputNoise : Voltage = 1.0e-9;

action def AmplifySignal {
in input : ElectricalSignal;
out output : ElectricalSignal;
}

action amplify : AmplifySignal {}
}

part def SignalProcessor {
port procInput : ElectricalInPort;
port dataOut : DataOutPort;
port cmdIn : CommandInPort;

attribute calibrationFactor : Dimensionless = 1.0;
attribute voltageOffset : Voltage = 0.0;
attribute saturationThreshold : RadiantPower = 1.0e-6;
attribute isCalibrated : Boolean = true;

action def ProcessMeasurement {
in signal : ElectricalSignal;
in command : String;
out data : MeasurementData;
}

action process : ProcessMeasurement {}

calc powerCalc : IncidentPowerCalc {}
}

// ===== Main System =====
part def CryogenicBolometer {
port opticalAperture : OpticalPort;
port commandPort : CommandInPort;
port dataPort : DataOutPort;

attribute systemMode : String = "standby";
attribute incidentPower : RadiantPower = 0.0;
attribute saturationThreshold : RadiantPower = 1.0e-6;
attribute calibrationComplete : Boolean = false;
attribute currentCommand : String = "none";

part absorber : AbsorberElement {}
part thermistor : ThermistorSensor {}
part heatSink : CryogenicHeatSink {}
part thermalIsolation : ThermalIsolationLink {}
part biasCircuit : BiasCircuit {}
part readoutAmplifier : ReadoutAmplifier {}
part signalProcessor : SignalProcessor {}

// Optical path
connection opticalPath connect opticalAperture to absorber.opticalIn {
flow radiation : ElectromagneticRadiation;
}

// Thermal path: absorber -> thermistor
connection absorberToThermistor connect absorber.thermalOut to thermistor.thermalIn {
flow heat : HeatFlow;
}

// Thermal path: thermistor -> isolation -> heat sink
connection thermistorToIsolation connect thermistor.thermalIsolationOut to thermalIsolation.sensorSide {
flow heat : HeatFlow;
}

connection isolationToSink connect thermalIsolation.sinkSide to heatSink.thermalIn {
flow heat : HeatFlow;
}

// Electrical path: bias circuit -> thermistor (bias drive)
connection biasToThermistor connect biasCircuit.biasDriveOut to thermistor.biasDriveIn {
flow signal : ElectricalSignal;
}

// Electrical path: thermistor -> bias circuit (sense)
connection thermistorToBias connect thermistor.electricalOut to biasCircuit.senseInput {
flow signal : ElectricalSignal;
}

// Electrical path: bias circuit -> amplifier
connection biasToAmplifier connect biasCircuit.senseOutput to readoutAmplifier.ampInput {
flow signal : ElectricalSignal;
}

// Electrical path: amplifier -> signal processor
connection amplifierToProcessor connect readoutAmplifier.ampOutput to signalProcessor.procInput {
flow signal : ElectricalSignal;
}

// Data output
connection processorToDataPort connect signalProcessor.dataOut to dataPort {
flow data : MeasurementData;
}

// Command input
connection commandToProcessor connect commandPort to signalProcessor.cmdIn;

// State Machine
state machine BolometerStateMachine {
state standby {
doc "Cooled and thermally stable, ready for command.";
entry { systemMode = "standby"; }
}

state measuring {
doc "Actively detecting radiation.";
entry { systemMode = "measuring"; }
}

state saturated {
doc "Incoming radiation too powerful, measurement unreliable.";
entry { systemMode = "saturated"; }
}

state calibrating {
doc "Calibration mode to ensure accurate readings.";
entry { systemMode = "calibrating"; }
}

transition init first then standby;

transition standby_to_measuring
first standby
if currentCommand == "measure"
then measuring;

transition measuring_to_saturated
first measuring
if incidentPower > saturationThreshold
then saturated;

transition measuring_to_standby
first measuring
if currentCommand == "stop"
then standby;

transition saturated_to_standby
first saturated
if currentCommand == "reset"
then standby;

transition standby_to_calibrating
first standby
if currentCommand == "calibrate"
then calibrating;

transition calibrating_to_standby
first calibrating
if calibrationComplete
then standby;
}
}

// ===== System Instance =====
part bolometerSystem : CryogenicBolometer;

// ===== Requirements =====
requirement def CryogenicTemperatureRequirement {
doc "The bolometer sensor assembly must be cooled to 4.2 K using liquid helium.";
subject bolometer : CryogenicBolometer;
require bolometer.heatSink.sinkTemperature == 4.2 [K];
}

requirement def AbsorptionEfficiencyRequirement {
doc "The absorber element must have an absorption efficiency of at least 90 percent.";
subject absorber : AbsorberElement;
require absorber.absorptionEfficiency >= 0.90;
}

requirement def AmplifierGainRequirement {
doc "The readout amplifier must provide a gain of 10000.";
subject amplifier : ReadoutAmplifier;
require amplifier.gain == 10000;
}

requirement def ThermalIsolationRequirement {
doc "The thermal isolation link must have a conductance no greater than 1e-8 W/K to allow slow heat dissipation.";
subject isolation : ThermalIsolationLink;
require isolation.thermalConductance <= 1.0e-8 ['W/K'];
}

requirement def SaturationDetectionRequirement {
doc "The system must enter the saturated state when incident power exceeds the threshold.";
subject bolometer : CryogenicBolometer;
require bolometer.incidentPower > bolometer.saturationThreshold implies bolometer.systemMode == "saturated";
}

requirement def CalibrationModeRequirement {
doc "The system must support a calibration mode for ensuring measurement accuracy.";
subject bolometer : CryogenicBolometer;
require bolometer.currentCommand == "calibrate" implies bolometer.systemMode == "calibrating";
}

requirement def BiasStabilityRequirement {
doc "The bias circuit must supply a stable voltage with stability better than 1 ppm.";
subject bias : BiasCircuit;
require bias.stability <= 1.0e-6;
}

requirement def MeasurementOutputRequirement {
doc "The system must output processed measurement data with valid incident power.";
subject bolometer : CryogenicBolometer;
require bolometer.dataPort.data.valid == true;
}

requirement def StandbyReadinessRequirement {
doc "The system must start in standby mode, cooled and thermally stable.";
subject bolometer : CryogenicBolometer;
require bolometer.systemMode == "standby";
}

// ===== Satisfaction =====
satisfy CryogenicTemperatureRequirement by bolometerSystem;
satisfy AbsorptionEfficiencyRequirement by bolometerSystem.absorber;
satisfy AmplifierGainRequirement by bolometerSystem.readoutAmplifier;
satisfy ThermalIsolationRequirement by bolometerSystem.thermalIsolation;
satisfy SaturationDetectionRequirement by bolometerSystem;
satisfy CalibrationModeRequirement by bolometerSystem;
satisfy BiasStabilityRequirement by bolometerSystem.biasCircuit;
satisfy MeasurementOutputRequirement by bolometerSystem;
satisfy StandbyReadinessRequirement by bolometerSystem;
}
