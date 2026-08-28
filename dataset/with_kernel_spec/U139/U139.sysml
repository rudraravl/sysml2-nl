package IntelligentEndotrachealTubeSystem {
    private import ISQ::*;
    private import ScalarValues::*;

    package Definitions {
        attribute def PressureValue :> Real;
        attribute def FlowRateValue :> Real;
        attribute def OxygenConcentrationValue :> Real;

        attribute def AirFlow;
        attribute def CuffPressure;
        attribute def SensorData {
            attribute pressure : PressureValue;
            attribute flowRate : FlowRateValue;
            attribute oxygenConcentration : OxygenConcentrationValue;
        }
        attribute def AlarmSignal {
            attribute severity : String;
            attribute alarmText : String;
        }

        attribute def AssessmentComplete;
        attribute def TubeInTrachea;
        attribute def CuffInflated;
        attribute def ParametersNeedTuning;
        attribute def CriticalConditionDetected;
        attribute def ParametersSet;
        attribute def IssueResolved;
        attribute def PatientUnableToBreathe;
        attribute def PatientBreathingResumed;

        port def AirFlowPort {
            in attribute air : AirFlow;
            out attribute returnAir : AirFlow;
        }
        port def DataOutPort {
            out attribute data : SensorData;
        }
        port def DataInPort {
            in attribute data : SensorData;
        }
        port def CuffPressurePort {
            in attribute pressure : CuffPressure;
        }
        port def AlarmPort {
            out attribute alarm : AlarmSignal;
        }

        part def Patient {
            part trachea;
            part lungs;
            port tracheaPort : AirFlowPort;
        }

        part def Ventilator {
            port airOut : AirFlowPort;
        }

        part def TubeBody {
            attribute material : String = "Medical-Grade PVC";
            port proximalEnd : AirFlowPort;
            port distalEnd : AirFlowPort;
        }

        part def InflatableCuff {
            port cuffInflationPort : CuffPressurePort;
            port proximalEnd : AirFlowPort;
            port distalEnd : AirFlowPort;
            attribute sealStatus : Boolean;
        }

        part def VentilationConnector {
            attribute standardDiameter : Integer = 15;
            port ventilatorPort : AirFlowPort;
            port tubePort : AirFlowPort;
        }

        part def PressureSensor {
            port dataOut : DataOutPort;
        }
        part def FlowSensor {
            port dataOut : DataOutPort;
        }
        part def OxygenSensor {
            port dataOut : DataOutPort;
        }

        part def SensorSuite {
            part pressureSensor : PressureSensor;
            part flowSensor : FlowSensor;
            part oxygenSensor : OxygenSensor;
        }

        part def ControlUnit {
            port dataIn : DataInPort;
            port alarmOut : AlarmPort;
            exhibit state ventilationModes : VentilationModes;
            perform action processSensorData : ProcessSensorData;
            perform action triggerAlarm : TriggerAlarm;
        }

        part def IntelligentEndotrachealTube {
            part tubeBody : TubeBody;
            part inflatableCuff : InflatableCuff;
            part ventilationConnector : VentilationConnector;
            part sensorSuite : SensorSuite;
            part controlUnit : ControlUnit;
            port alarmOut : AlarmPort;

            connect ventilationConnector.tubePort to tubeBody.proximalEnd;
            connect tubeBody.distalEnd to inflatableCuff.proximalEnd;
            connect sensorSuite.pressureSensor.dataOut to controlUnit.dataIn;
            connect sensorSuite.flowSensor.dataOut to controlUnit.dataIn;
            connect sensorSuite.oxygenSensor.dataOut to controlUnit.dataIn;
            connect controlUnit.alarmOut to alarmOut;
        }

        action def AssessPatient;
        action def InsertTube;
        action def InflateCuff;
        action def MonitorVitals;
        action def AdjustVentilation;
        action def HandleEmergency;
        action def ProcessSensorData {
            in data : SensorData;
        }
        action def TriggerAlarm {
            in condition : String;
        }

        state def TubeLifecycle {
            entry; then assessment;
            state assessment {
                entry action assessPatient : AssessPatient;
            }
            accept AssessmentComplete then insertion;
            state insertion {
                entry action insertTube : InsertTube;
            }
            accept TubeInTrachea then securing;
            state securing {
                entry action inflateCuff : InflateCuff;
            }
            accept CuffInflated then monitoring;
            state monitoring {
                entry action monitorVitals : MonitorVitals;
            }
            accept ParametersNeedTuning then adjust;
            accept CriticalConditionDetected then emergency;
            state adjust {
                entry action adjustVentilation : AdjustVentilation;
            }
            accept ParametersSet then monitoring;
            state emergency {
                entry action handleEmergency : HandleEmergency;
            }
            accept IssueResolved then adjust;
        }

        state def VentilationModes {
            entry; then spontaneousAssist;
            state spontaneousAssist;
            accept PatientUnableToBreathe then controlledBreaths;
            state controlledBreaths;
            accept PatientBreathingResumed then spontaneousAssist;
        }

        requirement def SecureAirwayReq {
            doc "The tube must establish and maintain a secure path for breathing.";
        }
        requirement def PreventAspirationReq {
            doc "The inflatable cuff shall create a seal to prevent aspiration of fluids.";
        }
        requirement def MonitorRespiratoryStatusReq {
            doc "The system must continuously monitor respiratory status.";
        }
        requirement def StandardConnectorReq {
            doc "The ventilation connector shall be a standardized 15mm interface.";
        }
    }

    import Definitions::*;

    package Usages {
        import Definitions::*;

        requirement secureAirwayReq : SecureAirwayReq;
        requirement preventAspirationReq : PreventAspirationReq;
        requirement monitorRespiratoryStatusReq : MonitorRespiratoryStatusReq;
        requirement standardConnectorReq : StandardConnectorReq;

        part systemContext {
            part ventilator : Ventilator;
            part patient : Patient;
            part ett : IntelligentEndotrachealTube {
                satisfy secureAirwayReq;
                satisfy preventAspirationReq;
                satisfy monitorRespiratoryStatusReq;
                satisfy standardConnectorReq;
                exhibit state lifecycle : TubeLifecycle;
            }

            connect ventilator.airOut to ett.ventilationConnector.ventilatorPort;
            connect ett.inflatableCuff.distalEnd to patient.tracheaPort;
        }
    }
}
