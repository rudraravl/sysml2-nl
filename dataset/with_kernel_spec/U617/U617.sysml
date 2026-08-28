package CryogenicBolometerSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    public import Definitions::*;
    public import Usages::*;

    package Definitions {
        item def EMRadiation {
            attribute power : PowerValue;
        }

        item def HeatFlow {
            attribute energy : EnergyValue;
        }

        item def ElectricalSignal {
            attribute voltage : VoltageValue;
        }

        item def PowerMeasurement {
            attribute value : PowerValue;
        }

        attribute def StartMeasurement;
        attribute def StopMeasurement;
        attribute def SaturationEvent;
        attribute def ResetCmd;
        attribute def CalibrateCmd;
        attribute def CalibrationDone;

        part def AbsorberElement {
            attribute coatingEmissivity : Real = 0.95;
            in item radIn : EMRadiation;
            out item heatOut : HeatFlow;
        }

        part def ThermistorSensor {
            attribute operatingTemperature : TemperatureValue = 4.2 [K];
            attribute baseResistance : ResistanceValue = 1000;
            attribute temperatureCoefficient : Real;
            in item heatIn : HeatFlow;
            in item biasIn : ElectricalSignal;
            out item heatDissipation : HeatFlow;
            out item sigOut : ElectricalSignal;
        }

        part def ThermalIsolationLink {
            attribute thermalConductance : Real;
            in item heatIn : HeatFlow;
            out item heatOut : HeatFlow;
        }

        part def CryogenicHeatSink {
            attribute sinkTemp : TemperatureValue = 4.2 [K];
            in item heatIn : HeatFlow;
        }

        part def BiasCircuit {
            attribute biasVoltage : VoltageValue = 0.001;
            out item biasOut : ElectricalSignal;
        }

        part def ReadoutAmplifier {
            attribute gain : Real = 10000;
            in item sigIn : ElectricalSignal;
            out item sigOut : ElectricalSignal;
        }

        part def SignalProcessor {
            attribute calibrationFactor : Real = 1.0;
            in item sigIn : ElectricalSignal;
            out item dataOut : PowerMeasurement;
        }

        action def 'Absorb Radiation' {
            in rad : EMRadiation;
            out heat : HeatFlow;
        }

        action def 'Transduce Heat to Signal' {
            in heat : HeatFlow;
            in bias : ElectricalSignal;
            out signal : ElectricalSignal;
        }

        action def 'Amplify Signal' {
            in inSig : ElectricalSignal;
            out outSig : ElectricalSignal;
        }

        action def 'Process Signal' {
            in inSig : ElectricalSignal;
            out outData : PowerMeasurement;
        }

        action def 'Perform Measurement' {
            in incidentRadiation : EMRadiation;
            in biasSignal : ElectricalSignal;
            out measuredPower : PowerMeasurement;

            action 'absorb radiation' : 'Absorb Radiation';
            flow 'absorb radiation'.heat to 'transduce'.heat;
            action 'transduce' : 'Transduce Heat to Signal';
            flow 'transduce'.signal to 'amplify'.inSig;
            action 'amplify' : 'Amplify Signal';
            flow 'amplify'.outSig to 'process'.inSig;
            action 'process' : 'Process Signal';
        }

        state def BolometerState {
            entry;
            then standby;

            state standby;

            transition t_standby_to_measuring
                first standby
                accept StartMeasurement
                then measuring;

            state measuring;

            transition t_measuring_to_saturated
                first measuring
                accept SaturationEvent
                then saturated;

            transition t_measuring_to_standby
                first measuring
                accept StopMeasurement
                then standby;

            transition t_standby_to_calibrating
                first standby
                accept CalibrateCmd
                then calibrating;

            state saturated;

            transition t_saturated_to_standby
                first saturated
                accept ResetCmd
                then standby;

            state calibrating;

            transition t_calibrating_to_standby
                first calibrating
                accept CalibrationDone
                then standby;
        }

        requirement CryogenicCoolingReq {
            doc /* The thermistor sensor shall be maintained at 4.2 K by the cryogenic heat sink. */
            subject sensor : ThermistorSensor;
            constraint { sensor.operatingTemperature == 4.2 [K]; }
        }

        requirement ThermalIsolationReq {
            doc /* A weak thermal link shall connect the sensor to the heat sink for controlled cooldown. */
            subject link : ThermalIsolationLink;
            constraint { link.thermalConductance < 1.0; }
        }

        requirement AmplificationReq {
            doc /* The readout amplifier shall boost the signal by a gain of 10000. */
            subject amp : ReadoutAmplifier;
            constraint { amp.gain == 10000; }
        }

        requirement MeasurementReq {
            doc /* The system shall convert incident radiation power into a calibrated power measurement. */
            subject processor : SignalProcessor;
            constraint { processor.calibrationFactor > 0; }
        }

        part def BolometerAssembly {
            in item radIn : EMRadiation;
            out item dataOut : PowerMeasurement;

            part absorber : AbsorberElement;
            part thermistor : ThermistorSensor;
            part thermalIsolation : ThermalIsolationLink;
            part heatSink : CryogenicHeatSink;
            part bias : BiasCircuit;
            part amplifier : ReadoutAmplifier;
            part processor : SignalProcessor;

            state bolometerState : BolometerState;

            flow radIn to absorber.radIn;
            flow absorber.heatOut to thermistor.heatIn;
            flow thermistor.heatDissipation to thermalIsolation.heatIn;
            flow thermalIsolation.heatOut to heatSink.heatIn;
            flow bias.biasOut to thermistor.biasIn;
            flow thermistor.sigOut to amplifier.sigIn;
            flow amplifier.sigOut to processor.sigIn;
            flow processor.dataOut to dataOut;
        }
    }

    package Usages {
        private import Definitions::*;

        part bolometerSystem : BolometerAssembly {
            satisfy CryogenicCoolingReq;
            satisfy ThermalIsolationReq;
            satisfy AmplificationReq;
            satisfy MeasurementReq;
        }
    }
}
