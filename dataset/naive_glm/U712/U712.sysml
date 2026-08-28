package HydrocarbonDewPointControlSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ---------- Value Types ----------
    def TemperatureValue :> Real {
        unit '°C';
    }
    def PressureValue :> Real {
        unit 'bar';
    }
    def FlowRateValue :> Real {
        unit 'm3/h';
    }
    def PowerValue :> Real {
        unit 'kW';
    }
    def FractionValue :> Real {
        unit 'percent';
    }
    def DewPointValue :> Real {
        unit '°C';
    }

    // ---------- Item Types ----------
    item def RawNaturalGas;
    item def ProcessedSalesGas;
    item def LiquidCondensate;
    item def ChilledGasLiquidMixture;
    item def Refrigerant;
    item def CoolingSignal;
    item def SensorReading;

    // ---------- Attributes ----------
    attribute def GasComposition {
        attribute methaneFraction : FractionValue;
        attribute ethaneFraction : FractionValue;
        attribute propaneFraction : FractionValue;
        attribute butaneFraction : FractionValue;
        attribute pentaneFraction : FractionValue;
    }

    attribute def SensorData {
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
        attribute dewPoint : DewPointValue;
        attribute flowRate : FlowRateValue;
    }

    attribute def ControlCommand {
        attribute coolingDemand : FractionValue;
        attribute timestamp : DateTime;
    }

    // ---------- Port Definitions ----------
    port def GasFlowPort {
        out item gas;
    }
    port def GasInPort {
        in item gas;
    }
    port def LiquidOutPort {
        out item liquid;
    }
    port def RefrigerantPort {
        out item refrigerant;
        in item returnRefrigerant;
    }
    port def SensorDataPort {
        out item reading : SensorReading;
    }
    port def ControlSignalPort {
        out item command : CoolingSignal;
    }

    // ---------- Requirements ----------
    requirement def MeetDewPointSpec {
        doc "The processed sales gas must meet the hydrocarbon dew point specification for pipeline transportation.";
        attribute maxDewPoint : DewPointValue = -5.0;
        subject salesGas : ProcessedSalesGas;
        require salesGas.dewPoint <= maxDewPoint;
    }

    requirement def ChillerCoolingCapacity {
        doc "The chiller unit must be capable of cooling raw natural gas to below -5°C under maximum flow conditions.";
        attribute targetTemperature : TemperatureValue = -5.0;
        attribute maxFlowRate : FlowRateValue = 50000.0;
        require chillerOutletTemperature <= targetTemperature;
    }

    requirement def SeparationEfficiency {
        doc "The separation vessel must remove at least 95% of condensed liquid from the gas stream.";
        attribute minEfficiency : FractionValue = 95.0;
        require separationEfficiency >= minEfficiency;
    }

    requirement def AutomatedControlResponse {
        doc "The process controller must adjust chiller cooling power automatically when dew point exceeds setpoint.";
        attribute maxResponseTime : DurationValue = 30.0;
        require responseTime <= maxResponseTime;
    }

    // ---------- Parts ----------

    part def TemperatureSensor {
        port dataOut : SensorDataPort;
        attribute measuredTemperature : TemperatureValue;
        action def measureTemperature {
            in gasStream : RawNaturalGas;
            out reading : SensorReading;
        }
    }

    part def PressureSensor {
        port dataOut : SensorDataPort;
        attribute measuredPressure : PressureValue;
        action def measurePressure {
            in gasStream : RawNaturalGas;
            out reading : SensorReading;
        }
    }

    part def DewPointAnalyzer {
        port dataOut : SensorDataPort;
        attribute measuredDewPoint : DewPointValue;
        attribute samplingInterval : DurationValue = 60.0;
        action def analyzeDewPoint {
            in gasStream : RawNaturalGas;
            out reading : SensorReading;
        }
        state def OperatingState {
            entry; then Measuring;
            state Measuring;
            transition Measuring to Reporting when measurementComplete;
            state Reporting;
            transition Reporting to Measuring when reportingComplete;
        }
    }

    part def ChillerUnit {
        port gasIn : GasInPort;
        port gasOut : GasFlowPort;
        port refrigerantIn : RefrigerantPort;
        port controlIn : ControlSignalPort;
        attribute outletTemperature : TemperatureValue;
        attribute coolingPower : PowerValue;
        attribute maxCoolingPower : PowerValue = 500.0;
        attribute heatTransferArea : Real = 200.0;
        action def chillGas {
            in rawGas : RawNaturalGas;
            in refrigerant : Refrigerant;
            in command : CoolingSignal;
            out chilledMixture : ChilledGasLiquidMixture;
        }
    }

    part def RefrigerationSystem {
        port refrigerantOut : RefrigerantPort;
        attribute refrigerantType : String = "Propane";
        attribute compressorPower : PowerValue;
        attribute evaporatorTemperature : TemperatureValue;
        attribute condenserTemperature : TemperatureValue;
        action def circulateRefrigerant {
            out refrigerant : Refrigerant;
            in returnRefrigerant : Refrigerant;
        }
        state def RefrigerationCycle {
            entry; then Compressing;
            state Compressing;
            transition Compressing to Condensing when compressionComplete;
            state Condensing;
            transition Condensing to Expanding when condensationComplete;
            state Expanding;
            transition Expanding to Evaporating when expansionComplete;
            state Evaporating;
            transition Evaporating to Compressing when evaporationComplete;
        }
    }

    part def SeparationVessel {
        port mixtureIn : GasInPort;
        port gasOut : GasFlowPort;
        port liquidOut : LiquidOutPort;
        attribute operatingPressure : PressureValue = 30.0;
        attribute liquidLevel : Real;
        attribute separationEfficiency : FractionValue;
        action def separatePhases {
            in mixture : ChilledGasLiquidMixture;
            out salesGas : ProcessedSalesGas;
            out condensate : LiquidCondensate;
        }
    }

    part def ProcessController {
        port sensorIn : SensorDataPort;
        port controlOut : ControlSignalPort;
        attribute dewPointSetpoint : DewPointValue = -5.0;
        attribute currentDewPoint : DewPointValue;
        attribute currentTemperature : TemperatureValue;
        attribute proportionalGain : Real = 1.5;
        attribute integralGain : Real = 0.1;
        attribute integralError : Real = 0.0;
        action def evaluateDewPoint {
            in reading : SensorReading;
            out command : CoolingSignal;
        }
        action def computeControlOutput {
            in error : Real;
            out demand : FractionValue;
        }
        state def ControlState {
            entry; then Monitoring;
            state Monitoring;
            transition Monitoring to Evaluating when sensorDataReceived;
            state Evaluating;
            transition Evaluating to Adjusting when dewPointExceedsSetpoint;
            transition Evaluating to Monitoring when dewPointWithinSpec;
            state Adjusting;
            transition Adjusting to Monitoring when commandSent;
        }
    }

    part def HydrocarbonDewPointControlSystem {
        doc "Automated industrial plant for processing raw natural gas to meet pipeline dew point specifications.";

        // Sub-parts
        part tempSensor : TemperatureSensor;
        part pressureSensor : PressureSensor;
        part dewPointAnalyzer : DewPointAnalyzer;
        part chiller : ChillerUnit;
        part refrigerationSystem : RefrigerationSystem;
        part separator : SeparationVessel;
        part controller : ProcessController;

        // External ports
        port rawGasInlet : GasInPort;
        port salesGasOutlet : GasFlowPort;
        port condensateOutlet : LiquidOutPort;

        // Connections
        connection rawGasToSensors connect rawGasInlet.gas to tempSensor;
        connection rawGasToPressure connect rawGasInlet.gas to pressureSensor;
        connection rawGasToAnalyzer connect rawGasInlet.gas to dewPointAnalyzer;

        connection tempSensorToController connect tempSensor.dataOut to controller.sensorIn;
        connection pressureSensorToController connect pressureSensor.dataOut to controller.sensorIn;
        connection analyzerToController connect dewPointAnalyzer.dataOut to controller.sensorIn;

        connection rawGasToChiller connect rawGasInlet.gas to chiller.gasIn;
        connection controllerToChiller connect controller.controlOut to chiller.controlIn;

        connection refrigerantToChiller connect refrigerationSystem.refrigerantOut to chiller.refrigerantIn;

        connection chillerToSeparator connect chiller.gasOut to separator.mixtureIn;
        connection separatorToSalesGas connect separator.gasOut to salesGasOutlet;
        connection separatorToCondensate connect separator.liquidOut to condensateOutlet;

        // Requirements satisfaction
        satisfy MeetDewPointSpec by salesGasOutlet;
        satisfy ChillerCoolingCapacity by chiller;
        satisfy SeparationEfficiency by separator;
        satisfy AutomatedControlResponse by controller;

        // System-level behavior
        action def ProcessNaturalGas {
            in rawGas : RawNaturalGas;
            out salesGas : ProcessedSalesGas;
            out condensate : LiquidCondensate;

            perform measureInletConditions {
                in gas = rawGas;
                out tempReading;
                out pressureReading;
                out dewPointReading;
            }

            perform chillGasStream {
                in gas = rawGas;
                in readings = tempReading;
                out chilledMixture;
            }

            perform separateMixture {
                in mixture = chilledMixture;
                out gas = salesGas;
                out liquid = condensate;
            }

            perform controlLoop {
                in readings = dewPointReading;
                out coolingCommand;
            }

            then chillGasStream;
        }

        state def SystemOperation {
            entry; then StartingUp;
            state StartingUp;
            transition StartingUp to NormalOperation when startupComplete;
            state NormalOperation;
            transition NormalOperation to Shutdown when shutdownRequested;
            state Shutdown;
            transition Shutdown to StartingUp when restartRequested;
        }
    }

    // ---------- Item flows ----------
    item def GasFlowItem {
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
        attribute composition : GasComposition;
    }

    flow def GasFlow {
        end : GasFlowPort;
        end : GasInPort;
        item : GasFlowItem;
    }

    flow def LiquidFlow {
        end : LiquidOutPort;
        item : LiquidCondensate;
    }

}
