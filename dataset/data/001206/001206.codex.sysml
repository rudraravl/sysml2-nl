package ProximitySensingUnitModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Percent :> Real;
    attribute def Count :> Integer;

    item def ElectricalPower {
        attribute voltage : Real [V];
        attribute current : Real [A];
    }

    item def ProximityEcho {
        attribute reflectedSignalStrength : Percent;
        attribute timeOfFlight : Real [s];
        attribute validEcho : Boolean;
    }

    item def DistanceMeasurement {
        attribute distance : Real [m];
        attribute confidence : Percent;
        attribute timestamp : Real [s];
    }

    item def PresenceIndication {
        attribute objectPresent : Boolean;
        attribute measuredDistance : Real [m];
        attribute confidence : Percent;
    }

    item def DiagnosticStatus {
        attribute healthy : Boolean;
        attribute faultCode : Count;
        attribute messageId : Count;
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    port def ExcitationPort {
        out item pulseCommand : ElectricalPower;
    }

    port def EchoPort {
        in item echo : ProximityEcho;
    }

    port def MeasurementOutputPort {
        out item measurement : DistanceMeasurement;
        out item presence : PresenceIndication;
        out item diagnostic : DiagnosticStatus;
    }

    port def DataBusPort {
        out item measurement : DistanceMeasurement;
        out item presence : PresenceIndication;
        out item diagnostic : DiagnosticStatus;
    }

    action def EmitProximityPulse {
        in item inputPower : ElectricalPower;
        out item emittedPulse : ElectricalPower;
    }

    action def ReceiveEcho {
        in item rawEcho : ProximityEcho;
        out item conditionedEcho : ProximityEcho;
    }

    action def ComputeDistance {
        in item conditionedEcho : ProximityEcho;
        out item distanceMeasurement : DistanceMeasurement;
    }

    action def EvaluatePresence {
        in item distanceMeasurement : DistanceMeasurement;
        out item presenceIndication : PresenceIndication;
    }

    action def ReportDiagnostics {
        in item conditionedEcho : ProximityEcho;
        out item diagnosticStatus : DiagnosticStatus;
    }

    part def PowerRegulator {
        port powerIn : PowerInputPort;
        port regulatedPowerOut : ExcitationPort;

        attribute nominalOutputVoltage : Real [V] = 5.0;
        attribute maximumOutputCurrent : Real [A] = 0.15;
        attribute conversionEfficiency : Percent = 88.0;
    }

    part def ProximitySensor {
        port excitationIn : ExcitationPort;
        port echoOut : EchoPort;

        attribute minimumRange : Real [m] = 0.02;
        attribute maximumRange : Real [m] = 2.00;
        attribute beamAngle : Real [deg] = 15.0;
        attribute updatePeriod : Real [s] = 0.050;
        attribute operatingFrequency : Real [Hz] = 40000.0;

        perform action emitPulse : EmitProximityPulse;
        perform action receiveEcho : ReceiveEcho;
    }

    part def SignalConditioner {
        port echoIn : EchoPort;
        port conditionedEchoOut : EchoPort;

        attribute noiseRejectionThreshold : Percent = 12.0;
        attribute minimumValidEchoStrength : Percent = 20.0;
        attribute filterTimeConstant : Real [s] = 0.010;
    }

    part def MeasurementProcessor {
        port echoIn : EchoPort;
        port measurementOut : MeasurementOutputPort;

        attribute speedOfSignal : Real [m/s] = 343.0;
        attribute detectionThresholdDistance : Real [m] = 0.75;
        attribute requiredConfidence : Percent = 80.0;
        attribute sampleCounter : Count;

        perform action computeDistance : ComputeDistance;
        perform action evaluatePresence : EvaluatePresence;
        perform action reportDiagnostics : ReportDiagnostics;

        state def ProcessingStateMachine {
            entry action initialize {
                sampleCounter = 0;
            }

            state Idle;
            state ExcitingSensor;
            state WaitingForEcho;
            state CalculatingDistance;
            state PublishingMeasurement;
            state FaultDetected;

            transition first Idle;

            transition Idle_to_ExcitingSensor
                first Idle then ExcitingSensor
                accept after 0.050 [s];

            transition ExcitingSensor_to_WaitingForEcho
                first ExcitingSensor then WaitingForEcho;

            transition WaitingForEcho_to_CalculatingDistance
                first WaitingForEcho then CalculatingDistance
                if echoIn.echo.validEcho == true;

            transition WaitingForEcho_to_FaultDetected
                first WaitingForEcho then FaultDetected
                if echoIn.echo.validEcho == false;

            transition CalculatingDistance_to_PublishingMeasurement
                first CalculatingDistance then PublishingMeasurement;

            transition PublishingMeasurement_to_Idle
                first PublishingMeasurement then Idle;

            transition FaultDetected_to_Idle
                first FaultDetected then Idle
                accept after 0.100 [s];
        }
    }

    part def CommunicationInterface {
        port measurementIn : MeasurementOutputPort;
        port dataBusOut : DataBusPort;

        attribute busBitRate : Real [Hz] = 500000.0;
        attribute messagePeriod : Real [s] = 0.050;
        attribute measurementMessageId : Count = 410;
        attribute diagnosticMessageId : Count = 411;
    }

    part def ProximitySensingUnit {
        port externalPower : PowerInputPort;
        port dataOut : DataBusPort;

        part regulator : PowerRegulator;
        part sensor : ProximitySensor;
        part conditioner : SignalConditioner;
        part processor : MeasurementProcessor;
        part interface : CommunicationInterface;

        attribute supplyVoltageMinimum : Real [V] = 9.0;
        attribute supplyVoltageMaximum : Real [V] = 32.0;
        attribute measurementRangeMinimum : Real [m] = 0.02;
        attribute measurementRangeMaximum : Real [m] = 2.00;
        attribute distanceAccuracy : Real [m] = 0.01;
        attribute responseTime : Real [s] = 0.100;
        attribute operatingTemperatureMinimum : Real [K] = 253.15;
        attribute operatingTemperatureMaximum : Real [K] = 358.15;

        connect externalPower.power to regulator.powerIn.power;
        connect regulator.regulatedPowerOut.pulseCommand to sensor.excitationIn.pulseCommand;
        connect sensor.echoOut.echo to conditioner.echoIn.echo;
        connect conditioner.conditionedEchoOut.echo to processor.echoIn.echo;
        connect processor.measurementOut.measurement to interface.measurementIn.measurement;
        connect processor.measurementOut.presence to interface.measurementIn.presence;
        connect processor.measurementOut.diagnostic to interface.measurementIn.diagnostic;
        connect interface.dataBusOut.measurement to dataOut.measurement;
        connect interface.dataBusOut.presence to dataOut.presence;
        connect interface.dataBusOut.diagnostic to dataOut.diagnostic;
    }

    requirement def MeasureProximityRequirement {
        doc /* The sensing unit shall measure distance to a nearby object using a proximity sensor. */
        subject sensingUnit : ProximitySensingUnit;

        require constraint {
            sensingUnit.measurementRangeMinimum <= 0.02 [m] and
            sensingUnit.measurementRangeMaximum >= 2.00 [m]
        }
    }

    requirement def PresenceDetectionRequirement {
        doc /* The sensing unit shall indicate object presence when measured distance is at or below the configured detection threshold. */
        subject processor : MeasurementProcessor;

        require constraint {
            processor.detectionThresholdDistance == 0.75 [m]
        }
    }

    requirement def AccuracyRequirement {
        doc /* The sensing unit shall report distance with accuracy of 10 millimeters or better within its valid measurement range. */
        subject sensingUnit : ProximitySensingUnit;

        require constraint {
            sensingUnit.distanceAccuracy <= 0.01 [m]
        }
    }

    requirement def ResponseTimeRequirement {
        doc /* The sensing unit shall publish a distance measurement and presence indication within 100 milliseconds of a valid proximity echo. */
        subject sensingUnit : ProximitySensingUnit;

        require constraint {
            sensingUnit.responseTime <= 0.100 [s]
        }
    }

    requirement def DiagnosticRequirement {
        doc /* The sensing unit shall report diagnostic status when no valid proximity echo is received during a measurement cycle. */
        subject processor : MeasurementProcessor;

        require constraint {
            processor.requiredConfidence >= 80.0
        }
    }

    requirement def PowerRequirement {
        doc /* The sensing unit shall operate from a nominal external DC supply range of 9 to 32 volts. */
        subject sensingUnit : ProximitySensingUnit;

        require constraint {
            sensingUnit.supplyVoltageMinimum <= 9.0 [V] and
            sensingUnit.supplyVoltageMaximum >= 32.0 [V]
        }
    }

    satisfy MeasureProximityRequirement by ProximitySensingUnit;
    satisfy PresenceDetectionRequirement by MeasurementProcessor;
    satisfy AccuracyRequirement by ProximitySensingUnit;
    satisfy ResponseTimeRequirement by ProximitySensingUnit;
    satisfy DiagnosticRequirement by MeasurementProcessor;
    satisfy PowerRequirement by ProximitySensingUnit;

    part proximitySensingUnit : ProximitySensingUnit;

}