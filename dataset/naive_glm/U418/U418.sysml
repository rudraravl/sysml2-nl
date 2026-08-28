package MedicalVentilationSystem {

    // ---- Value types with units ----
    package Units {
        value def PressureValue :> Real { unit 'mmHg'; }
        value def VolumeValue :> Real { unit 'mL'; }
        value def FlowValue :> Real { unit 'L/min'; }
        value def FrequencyValue :> Real { unit 'breaths/min'; }
        value def FractionValue :> Real { unit '%'; }
        value def LengthValue :> Real { unit 'mm'; }
        value def DiameterValue :> Real { unit 'mm'; }
    }

    // ---- Item definitions ----
    item def Air {
        attribute oxygenConcentration : FractionValue;
        attribute pressure : PressureValue;
        attribute flow : FlowValue;
    }

    item def Breath {
        attribute tidalVolume : VolumeValue;
        attribute oxygenConcentration : FractionValue;
        attribute rate : FrequencyValue;
    }

    // ---- Port definitions ----
    port def AirPort {
        in air : Air;
        out airOut : Air;
    }

    port def PressurePort {
        out pressure : PressureValue;
    }

    port def FlowPort {
        out flow : FlowValue;
    }

    // ---- Requirements ----
    requirement def SecureAirwayRequirement {
        doc /* The system shall establish and maintain a secure artificial airway. */
        subject : MedicalVentilationSystem;
        requirement secureAirway :> SecureAirwayRequirement {
            doc /* The tracheal tube shall provide a sealed conduit between the ventilator and the patient's trachea. */
        }
    }

    requirement def CuffPressureRequirement {
        doc /* The cuff shall be inflated to a safe pressure to seal without causing injury. */
        subject cuff : TrachealTube::Cuff;
        attribute minSafePressure : PressureValue = 20 [mmHg];
        attribute maxSafePressure : PressureValue = 30 [mmHg];
        requirement safePressure :> CuffPressureRequirement {
            doc /* Cuff pressure shall be between minSafePressure and maxSafePressure. */
        }
    }

    requirement def VentilationRequirement {
        doc /* The ventilator shall deliver controlled breaths with specified tidal volume, rate, and oxygen concentration. */
        subject ventilator : Ventilator;
        attribute targetTidalVolume : VolumeValue = 500 [mL];
        attribute targetRate : FrequencyValue = 12 [breaths/min];
        attribute targetOxygen : FractionValue = 40 [%];
    }

    requirement def MonitoringRequirement {
        doc /* The system shall monitor airway pressure and airflow. */
        subject system : MedicalVentilationSystem;
        requirement pressureMonitoring :> MonitoringRequirement {
            doc /* Airway pressure shall be continuously monitored. */
        }
        requirement flowMonitoring :> MonitoringRequirement {
            doc /* Airflow shall be continuously monitored. */
        }
    }

    // ---- Component definitions ----

    part def Patient {
        attribute isBreathing : Boolean;
        port airwayPort : AirPort;
        part lungs {
            port lungPort : AirPort;
        }
        part trachea {
            port trachealPort : AirPort;
            attribute trachealDiameter : DiameterValue = 20 [mm];
        }
        connection tracheaToLungs connect trachea.trachealPort to lungs.lungPort;
        connection airwayToTrachea connect airwayPort to trachea.trachealPort;
    }

    part def TrachealTube {
        attribute length : LengthValue = 300 [mm];
        attribute innerDiameter : DiameterValue = 8 [mm];
        attribute outerDiameter : DiameterValue = 11 [mm];

        port proximalPort : AirPort;
        port distalPort : AirPort;

        part lumen {
            doc /* Main channel for air passage. */
            port lumenIn : AirPort;
            port lumenOut : AirPort;
            connection lumenFlow connect lumenIn to lumenOut;
        }

        part cuff {
            doc /* Inflatable cuff near the tip to seal against tracheal wall. */
            attribute isInflated : Boolean;
            attribute cuffPressure : PressureValue;
            attribute maxDiameter : DiameterValue = 22 [mm];
            port inflationPort;
            action inflate :>> CuffInflateAction;
            action deflate :>> CuffDeflateAction;
        }

        part beveledTip {
            doc /* Specially designed tip for easier, less traumatic insertion. */
            attribute bevelAngle : Real = 45;
        }

        part murphyEye {
            doc /* Safety opening to ensure airflow if main tip is blocked. */
            attribute isOpen : Boolean = true;
            port eyePort : AirPort;
        }

        connection proximalToLumen connect proximalPort to lumen.lumenIn;
        connection lumenToDistal connect lumen.lumenOut to distalPort;
        connection lumenToMurphyEye connect lumen.lumenOut to murphyEye.eyePort;

        state def TubeLifecycle {
            entry; then Prepared;
            state Prepared {
                doc /* Tube is prepared for insertion. */
                entry; then Inserting;
            }
            state Inserting {
                doc /* Tube is being inserted into the trachea. */
                accept InsertionComplete; then CuffInflating;
            }
            state CuffInflating {
                doc /* Cuff is being inflated to safe pressure. */
                entry action { cuff.inflate(); }
                accept CuffSealed; then Ventilating;
            }
            state Ventilating {
                doc /* Ventilator delivers controlled breaths through the tube. */
                accept VentilationComplete; then CuffDeflating;
            }
            state CuffDeflating {
                doc /* Cuff is deflated before removal. */
                entry action { cuff.deflate(); }
                accept CuffDeflated; then Removing;
            }
            state Removing {
                doc /* Tube is removed from the patient. */
                accept RemovalComplete; then done;
            }
        }

        exhibit state behavior : TubeLifecycle;
    }

    part def Ventilator {
        doc /* Life-support machine controlling the breathing process. */
        attribute tidalVolume : VolumeValue = 500 [mL];
        attribute breathingRate : FrequencyValue = 12 [breaths/min];
        attribute oxygenConcentration : FractionValue = 40 [%];
        attribute isOperating : Boolean;

        port ventilatorPort : AirPort;
        port pressureMonitorPort : PressurePort;
        port flowMonitorPort : FlowPort;

        action def DeliverBreath {
            in breath : Breath;
            out deliveredAir : Air;
        }

        action def MonitorPressure {
            out pressure : PressureValue;
        }

        action def MonitorFlow {
            out flow : FlowValue;
        }

        state def VentilatorOperation {
            entry; then Idle;
            state Idle {
                accept StartVentilation; then Delivering;
            }
            state Delivering {
                doc /* Delivers controlled breaths to the patient. */
                entry action {
                    deliverBreath();
                    monitorPressure();
                    monitorFlow();
                }
                accept StopVentilation; then Idle;
            }
        }

        exhibit state behavior : VentilatorOperation;

        private action deliverBreath : DeliverBreath;
        private action monitorPressure : MonitorPressure;
        private action monitorFlow : MonitorFlow;
    }

    part def PressureMonitor {
        attribute measuredPressure : PressureValue;
        port pressurePort : PressurePort;
        action def MeasurePressure {
            out pressure : PressureValue;
        }
        action measure : MeasurePressure;
    }

    part def FlowMonitor {
        attribute measuredFlow : FlowValue;
        port flowPort : FlowPort;
        action def MeasureFlow {
            out flow : FlowValue;
        }
        action measure : MeasureFlow;
    }

    // ---- Actions for cuff operations ----
    action def CuffInflateAction {
        in targetPressure : PressureValue = 25 [mmHg];
        out cuffPressure : PressureValue;
    }

    action def CuffDeflateAction {
        out cuffPressure : PressureValue = 0 [mmHg];
    }

    // ---- Top-level system ----
    part def MedicalVentilationSystem {
        part patient : Patient;
        part trachealTube : TrachealTube;
        part ventilator : Ventilator;
        part pressureMonitor : PressureMonitor;
        part flowMonitor : FlowMonitor;

        connection ventilatorToTube connect ventilator.ventilatorPort to trachealTube.proximalPort;
        connection tubeToPatient connect trachealTube.distalPort to patient.airwayPort;
        connection tubePressureMonitor connect trachealTube.proximalPort to pressureMonitor.pressurePort;
        connection tubeFlowMonitor connect trachealTube.proximalPort to flowMonitor.flowPort;

        // System-level procedure
        action def IntubationProcedure {
            doc /* Clinical procedure for intubation and mechanical ventilation. */
            action prepareTube {
                doc /* Prepare the tracheal tube for insertion. */
            }
            action insertTube {
                doc /* Insert the tube into the patient's trachea. */
            }
            action inflateCuff {
                doc /* Inflate the cuff to a safe pressure. */
                in targetPressure : PressureValue = 25 [mmHg];
            }
            action connectVentilator {
                doc /* Connect the ventilator to the tube. */
            }
            action ventilate {
                doc /* Deliver controlled breaths and monitor. */
            }
            action deflateCuff {
                doc /* Deflate the cuff. */
            }
            action removeTube {
                doc /* Remove the tube from the patient. */
            }

            flow from prepareTube.out to insertTube.in;
            flow from insertTube.out to inflateCuff.in;
            flow from inflateCuff.out to connectVentilator.in;
            flow from connectVentilator.out to ventilate.in;
            flow from ventilate.out to deflateCuff.in;
            flow from deflateCuff.out to removeTube.in;
        }

        perform action :>> IntubationProcedure;

        satisfy secureAirwayRequirement :> SecureAirwayRequirement by trachealTube;
        satisfy cuffPressureRequirement :> CuffPressureRequirement by trachealTube.cuff;
        satisfy ventilationRequirement :> VentilationRequirement by ventilator;
        satisfy monitoringRequirement :> MonitoringRequirement by (pressureMonitor, flowMonitor);
    }

    // ---- Signal definitions for state transitions ----
    item def InsertionComplete;
    item def CuffSealed;
    item def VentilationComplete;
    item def CuffDeflated;
    item def RemovalComplete;
    item def StartVentilation;
    item def StopVentilation;

}
