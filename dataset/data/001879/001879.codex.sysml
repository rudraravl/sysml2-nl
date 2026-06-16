package TotalPressureSystemModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    value def PressureValue {
        :>> unit = "Pa";
        :>> quantityKind = "pressure";
    }

    value def TemperatureValue {
        :>> unit = "K";
        :>> quantityKind = "thermodynamicTemperature";
    }

    value def VelocityValue {
        :>> unit = "m/s";
        :>> quantityKind = "speed";
    }

    value def DensityValue {
        :>> unit = "kg/m^3";
        :>> quantityKind = "density";
    }

    value def VoltageValue {
        :>> unit = "V";
        :>> quantityKind = "electricPotential";
    }

    item def AirStream {
        attribute staticPressure : PressureValue;
        attribute totalPressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute density : DensityValue;
        attribute flowVelocity : VelocityValue;
    }

    item def PneumaticPressure {
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
    }

    item def ElectricalPressureSignal {
        attribute voltage : VoltageValue;
        attribute representedPressure : PressureValue;
        attribute valid : Boolean;
    }

    item def AirDataMessage {
        attribute totalPressure : PressureValue;
        attribute staticPressure : PressureValue;
        attribute dynamicPressure : PressureValue;
        attribute computedAirspeed : VelocityValue;
        attribute dataValid : Boolean;
    }

    port def AirInletPort {
        in item incomingAir : AirStream;
    }

    port def PneumaticPort {
        inout item pressureMedium : PneumaticPressure;
    }

    port def SignalPort {
        out item signal : ElectricalPressureSignal;
    }

    port def DataPort {
        out item message : AirDataMessage;
    }

    port def PowerPort {
        in attribute supplyVoltage : VoltageValue;
    }

    part def TotalPressureProbe {
        port inlet : AirInletPort;
        port sensedPressure : PneumaticPort;

        attribute captureEfficiency : Real = 0.995;
        attribute icingBlocked : Boolean = false;

        action def CaptureTotalPressure {
            in item air : AirStream;
            out item captured : PneumaticPressure;

            action computeCapturedPressure {
                captured.pressure := air.totalPressure * captureEfficiency;
                captured.temperature := air.temperature;
            }
        }
    }

    part def PneumaticLine {
        port upstream : PneumaticPort;
        port downstream : PneumaticPort;

        attribute volume : Real = 0.000015;
        attribute leakRate : Real = 0.0;
        attribute pressureLagTime : Real = 0.08;
    }

    part def PressureTransducer {
        port pressureInput : PneumaticPort;
        port power : PowerPort;
        port electricalOutput : SignalPort;

        attribute measurementRangeMin : PressureValue = 15000;
        attribute measurementRangeMax : PressureValue = 120000;
        attribute accuracy : PressureValue = 35;
        attribute powered : Boolean;

        action def ConvertPressureToVoltage {
            in item pneumatic : PneumaticPressure;
            in attribute supply : VoltageValue;
            out item outputSignal : ElectricalPressureSignal;

            action conversion {
                outputSignal.representedPressure := pneumatic.pressure;
                outputSignal.voltage := 0.5 + 4.0 * ((pneumatic.pressure - measurementRangeMin) / (measurementRangeMax - measurementRangeMin));
                outputSignal.valid := supply >= 4.75 and supply <= 5.25 and pneumatic.pressure >= measurementRangeMin and pneumatic.pressure <= measurementRangeMax;
            }
        }
    }

    part def AirDataProcessor {
        port totalPressureSignal : SignalPort;
        port outputData : DataPort;

        attribute assumedStaticPressure : PressureValue = 101325;
        attribute assumedAirDensity : DensityValue = 1.225;
        attribute currentTotalPressure : PressureValue;
        attribute currentDynamicPressure : PressureValue;
        attribute currentAirspeed : VelocityValue;
        attribute validData : Boolean;

        action def ComputeAirData {
            in item pressureSignal : ElectricalPressureSignal;
            out item data : AirDataMessage;

            action calculateDynamicPressure {
                currentTotalPressure := pressureSignal.representedPressure;
                currentDynamicPressure := currentTotalPressure - assumedStaticPressure;
                currentAirspeed := sqrt((2.0 * currentDynamicPressure) / assumedAirDensity);
                validData := pressureSignal.valid and currentDynamicPressure >= 0;
            }

            action publishMessage {
                data.totalPressure := currentTotalPressure;
                data.staticPressure := assumedStaticPressure;
                data.dynamicPressure := currentDynamicPressure;
                data.computedAirspeed := currentAirspeed;
                data.dataValid := validData;
            }
        }

        state def ProcessorStateMachine {
            state powerOff;
            state initializing;
            state monitoring;
            state degraded;
            state faulted;

            transition first powerOff then initializing
                accept PowerApplied;

            transition initializing then monitoring
                accept SelfTestPassed;

            transition initializing then faulted
                accept SelfTestFailed;

            transition monitoring then degraded
                accept PressureSignalOutOfRange;

            transition degraded then monitoring
                accept SignalRecovered;

            transition monitoring then faulted
                accept SensorFailure;

            transition degraded then faulted
                accept SensorFailure;

            transition faulted then initializing
                accept ResetCommand;
        }
    }

    part def TotalPressureBasedSystem {
        port airInlet : AirInletPort;
        port powerInput : PowerPort;
        port airDataOutput : DataPort;

        part probe : TotalPressureProbe;
        part pneumaticLine : PneumaticLine;
        part transducer : PressureTransducer;
        part processor : AirDataProcessor;

        connect airInlet to probe.inlet;
        connect probe.sensedPressure to pneumaticLine.upstream;
        connect pneumaticLine.downstream to transducer.pressureInput;
        connect powerInput to transducer.power;
        connect transducer.electricalOutput to processor.totalPressureSignal;
        connect processor.outputData to airDataOutput;

        action def PrimaryFunction {
            in item externalAir : AirStream;
            out item airData : AirDataMessage;

            action acquireTotalPressure {
                send externalAir to probe.inlet;
            }

            action transmitPressure {
                flow probe.sensedPressure.pressureMedium to pneumaticLine.upstream.pressureMedium;
                flow pneumaticLine.downstream.pressureMedium to transducer.pressureInput.pressureMedium;
            }

            action sensePressure {
                perform transducer.ConvertPressureToVoltage;
            }

            action computeAndPublish {
                perform processor.ComputeAirData;
                airData := processor.outputData.message;
            }
        }

        state def SystemStateMachine {
            state off;
            state standby;
            state sensingTotalPressure;
            state computingAirData;
            state publishing;
            state maintenanceRequired;
            state failed;

            transition first off then standby
                accept PowerApplied;

            transition standby then sensingTotalPressure
                accept AirflowDetected;

            transition sensingTotalPressure then computingAirData
                accept PressureCaptured;

            transition computingAirData then publishing
                accept AirDataComputed;

            transition publishing then sensingTotalPressure
                accept NextSamplePeriod;

            transition sensingTotalPressure then maintenanceRequired
                accept ProbeBlocked;

            transition computingAirData then failed
                accept ComputationInvalid;

            transition maintenanceRequired then standby
                accept MaintenanceCleared;

            transition failed then standby
                accept ResetCommand;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject system : TotalPressureBasedSystem;

        doc /* The system shall use total pressure as the principal sensed quantity to estimate dynamic pressure and publish high-level air data. */

        require constraint {
            system.processor.currentDynamicPressure == system.processor.currentTotalPressure - system.processor.assumedStaticPressure
        }
    }

    requirement def TotalPressureRangeRequirement {
        subject transducer : PressureTransducer;

        require constraint {
            transducer.measurementRangeMin <= 15000 and transducer.measurementRangeMax >= 120000
        }
    }

    requirement def ValidOutputRequirement {
        subject processor : AirDataProcessor;

        require constraint {
            processor.validData implies processor.currentDynamicPressure >= 0
        }
    }

    requirement def PowerQualityRequirement {
        subject transducer : PressureTransducer;

        require constraint {
            transducer.power.supplyVoltage >= 4.75 and transducer.power.supplyVoltage <= 5.25
        }
    }

    requirement def FaultHandlingRequirement {
        subject system : TotalPressureBasedSystem;

        doc /* The system shall transition to a degraded or failed condition when the total pressure signal is unavailable, implausible, or outside the calibrated range. */
    }

    satisfy PrimaryFunctionRequirement by TotalPressureBasedSystem::PrimaryFunction;
    satisfy TotalPressureRangeRequirement by PressureTransducer;
    satisfy ValidOutputRequirement by AirDataProcessor::ComputeAirData;
    satisfy PowerQualityRequirement by PressureTransducer;
    satisfy FaultHandlingRequirement by TotalPressureBasedSystem::SystemStateMachine;
}