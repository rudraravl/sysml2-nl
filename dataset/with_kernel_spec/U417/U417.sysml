package TrachealIntubationSystem {
    doc
    /*
     * Complete medical system for tracheal intubation, including devices,
     * clinical workflow, patient monitoring, and safety requirements.
     */

    private import ScalarValues::*;

    attribute def PressureValue :> Real;
    attribute def VolumeValue :> Real;
    attribute def FlowRateValue :> Real;
    attribute def FrequencyValue :> Real;
    attribute def LengthValue :> Real;
    attribute def MassValue :> Real;
    attribute def FractionValue :> Real;

    item def GasMixture {
        attribute oxygenFraction : FractionValue;
        attribute flowRate : FlowRateValue;
    }

    attribute def PatientVitalSigns {
        attribute spO2 : FractionValue;
        attribute etCO2 : PressureValue;
        attribute heartRate : FrequencyValue;
        attribute airwayPressure : PressureValue;
    }

    item def AlarmEvent {
        attribute alarmType : String;
        attribute alarmMessage : String;
    }

    item def Secretion;

    attribute def StartVentilation;
    attribute def StopVentilation;
    attribute def HighPressureAlarm;
    attribute def ResetAlarm;
    attribute def StartMonitoring;
    attribute def StopMonitoring;
    attribute def VitalsOutOfRange;
    attribute def VitalsNormal;
    attribute def VolumeDelivered;
    attribute def CycleComplete;

    port def GasFlowPort {
        attribute pressure : PressureValue;
    }

    port def CuffInflationPort {
        attribute pressure : PressureValue;
    }

    port def SensorOutputPort;

    port def SuctionPort;

    port def AlarmPort;

    state def VentilatorStates {
        entry; then Idle;
        state Idle {
            accept StartVentilation then Ventilating;
        }
        state Ventilating {
            accept VolumeDelivered then Exhaling;
            accept HighPressureAlarm then AlarmState;
            accept StopVentilation then Idle;
        }
        state Exhaling {
            accept CycleComplete then Ventilating;
            accept HighPressureAlarm then AlarmState;
        }
        state AlarmState {
            accept ResetAlarm then Idle;
        }
    }

    state def MonitorStates {
        entry; then Idle;
        state Idle {
            accept StartMonitoring then Monitoring;
        }
        state Monitoring {
            accept VitalsOutOfRange then AlarmState;
            accept StopMonitoring then Idle;
        }
        state AlarmState {
            accept VitalsNormal then Monitoring;
            accept StopMonitoring then Idle;
        }
    }

    part def EndotrachealTube {
        doc
        /*
         * Flexible tube inserted through the mouth into the trachea
         * to establish a secure airway.
         */
        attribute tubeDiameter : LengthValue;
        attribute tubeLength : LengthValue;
        part cuff : InflatableCuff[1];
        port proximalEnd : GasFlowPort;
        port distalEnd : GasFlowPort;
    }

    part def InflatableCuff {
        doc
        /*
         * Inflatable balloon at the distal end of the tube that seals
         * against the tracheal wall when filled with air.
         */
        attribute maxVolume : VolumeValue;
        attribute currentPressure : PressureValue;
        attribute targetPressure : PressureValue;
        port inflationPort : CuffInflationPort;
        action inflate {
            in target : PressureValue;
            out actual : PressureValue;
        }
        action deflate;
    }

    part def Laryngoscope {
        doc
        /*
         * Handheld instrument with a light source and blade for
         * visualizing the vocal cords during intubation.
         */
        part blade : LaryngoscopeBlade[1];
        part handle : LaryngoscopeHandle[1];
        part lightSource : LightSource[1];
        action activateLight;
        action deactivateLight;
    }

    part def LaryngoscopeBlade {
        attribute bladeSize : LengthValue;
        attribute bladeType : String;
    }

    part def LaryngoscopeHandle {
        attribute batteryLevel : FractionValue;
    }

    part def LightSource {
        attribute isActive : Boolean;
    }

    part def MechanicalVentilator {
        doc
        /*
         * Machine that delivers controlled breaths of an air-oxygen
         * mixture to the patient through the endotracheal tube.
         */
        attribute tidalVolume : VolumeValue;
        attribute respiratoryRate : Real;
        attribute fiO2 : FractionValue;
        attribute peep : PressureValue;
        attribute maxPressureLimit : PressureValue;
        attribute currentAirwayPressure : PressureValue;
        port gasOutlet : GasFlowPort;
        port alarmOutput : AlarmPort;

        action deliverBreath {
            in volume : VolumeValue;
            in oxygenFraction : FractionValue;
        }

        action monitorPressure {
            out pressure : PressureValue;
        }
    }

    part def PatientMonitor {
        doc
        /*
         * Device that continuously tracks patient vital signs including
         * SpO2, EtCO2, and heart rate.
         */
        port sensorInput : SensorOutputPort;
        port alarmOutput : AlarmPort;
        attribute currentVitals : PatientVitalSigns;

        action measureVitals {
            out vitals : PatientVitalSigns;
        }

        action updateDisplay {
            in vitals : PatientVitalSigns;
        }
    }

    part def SuctionDevice {
        doc
        /*
         * Device for clearing secretions from the airway to maintain patency.
         */
        attribute suctionPressure : PressureValue;
        port suctionTip : SuctionPort;
        action activateSuction;
        action deactivateSuction;
    }

    part def Syringe {
        doc
        /*
         * Device used to inflate the endotracheal tube cuff to target pressure.
         */
        attribute capacity : VolumeValue;
        port outlet : CuffInflationPort;
    }

    part def Patient {
        doc
        /*
         * The patient undergoing tracheal intubation.
         */
        attribute idealBodyWeight : MassValue;
        port mouth : GasFlowPort;
        port trachea : GasFlowPort;
        port vitalSignsOutput : SensorOutputPort;
    }

    connection def GasFlowConnection {
        end source : GasFlowPort[1];
        end target : GasFlowPort[1];
    }

    connection def CuffInflationConnection {
        end source : CuffInflationPort[1];
        end target : CuffInflationPort[1];
    }

    connection def SuctionConnection {
        end source : SuctionPort[1];
        end target : GasFlowPort[1];
    }

    connection def SensorConnection {
        end source : SensorOutputPort[1];
        end target : SensorOutputPort[1];
    }

    part def IntubationSystem {
        doc
        /*
         * Complete tracheal intubation system assembly.
         */
        part patient : Patient[1];
        part tube : EndotrachealTube[1];
        part laryngoscope : Laryngoscope[1];
        part ventilator : MechanicalVentilator[1];
        part monitor : PatientMonitor[1];
        part suction : SuctionDevice[1];
        part syringe : Syringe[1];

        connection ventilatorToTube : GasFlowConnection
            connect ventilator.gasOutlet to tube.proximalEnd;
        connection tubeToPatient : GasFlowConnection
            connect tube.distalEnd to patient.trachea;
        connection cuffInflation : CuffInflationConnection
            connect syringe.outlet to tube.cuff.inflationPort;
        connection suctionToAirway : SuctionConnection
            connect suction.suctionTip to patient.mouth;
        connection monitorToPatient : SensorConnection
            connect patient.vitalSignsOutput to monitor.sensorInput;
    }

    calc def CheckCuffPressure {
        in current : PressureValue;
        in min : PressureValue;
        in max : PressureValue;
        return isValid : Boolean = current >= min and current <= max;
    }

    action def IntubationProcedure {
        doc
        /*
         * Step-by-step procedure for performing tracheal intubation.
         */
        in patient : Patient;
        in tube : EndotrachealTube;
        in scope : Laryngoscope;
        in ventilator : MechanicalVentilator;
        in monitor : PatientMonitor;
        in suction : SuctionDevice;
        in syringe : Syringe;

        action preparePatient;
        action prepareEquipment;
        action performLaryngoscopy;
        action insertTube;
        action confirmPlacement;
        action secureTube;
        action initiateMonitoring;

        first start;
        then preparePatient;
        then prepareEquipment;
        then performLaryngoscopy;
        then insertTube;
        then confirmPlacement;
        then secureTube;
        then initiateMonitoring;
        then done;
    }

    requirement def CuffPressureRequirement {
        doc
        /*
         * The endotracheal tube cuff pressure shall be maintained between
         * 20 and 30 cmH2O (approximately 1961-2942 Pa) to prevent tracheal
         * injury while ensuring an adequate seal.
         */
        subject tube : EndotrachealTube;
        attribute minPressure : PressureValue = 1961.0;
        attribute maxPressure : PressureValue = 2942.0;
        require constraint {
            tube.cuff.currentPressure >= minPressure and
            tube.cuff.currentPressure <= maxPressure
        }
    }

    requirement def VentilationRequirement {
        doc
        /*
         * The ventilator shall deliver a tidal volume of 6-8 mL/kg of
         * ideal body weight at a respiratory rate of 12-20 breaths per minute.
         */
        subject ventilator : MechanicalVentilator;
        attribute minTidalVolumePerKg : FractionValue = 0.006;
        attribute maxTidalVolumePerKg : FractionValue = 0.008;
        attribute minRespRate : Real = 12.0;
        attribute maxRespRate : Real = 20.0;
        require constraint {
            ventilator.tidalVolume >= minTidalVolumePerKg * 70.0 and
            ventilator.tidalVolume <= maxTidalVolumePerKg * 70.0 and
            ventilator.respiratoryRate >= minRespRate and
            ventilator.respiratoryRate <= maxRespRate
        }
    }

    requirement def AirwayPressureAlarmRequirement {
        doc
        /*
         * The ventilator shall trigger a high-pressure alarm if peak
         * airway pressure exceeds 40 cmH2O (approximately 3923 Pa).
         */
        subject ventilator : MechanicalVentilator;
        attribute maxAirwayPressure : PressureValue = 3923.0;
        require constraint {
            ventilator.maxPressureLimit <= maxAirwayPressure
        }
    }

    requirement def OxygenSaturationRequirement {
        doc
        /*
         * The patient monitor shall trigger an alarm if SpO2 falls below 90%.
         */
        subject monitor : PatientMonitor;
        attribute minSpO2 : FractionValue = 90.0;
        require constraint {
            monitor.currentVitals.spO2 >= minSpO2
        }
    }

    requirement def EtCO2ConfirmationRequirement {
        doc
        /*
         * Correct endotracheal tube placement shall be confirmed by
         * detecting end-tidal CO2 within the normal range of 35-45 mmHg
         * (approximately 4666-6000 Pa).
         */
        subject monitor : PatientMonitor;
        attribute minEtCO2 : PressureValue = 4666.0;
        attribute maxEtCO2 : PressureValue = 6000.0;
        require constraint {
            monitor.currentVitals.etCO2 >= minEtCO2 and
            monitor.currentVitals.etCO2 <= maxEtCO2
        }
    }

    requirement def SecureAirwayRequirement {
        doc
        /*
         * The system must establish and maintain a secure airway with
         * the endotracheal tube correctly placed in the trachea.
         */
        subject tube : EndotrachealTube;
        require constraint {
            tube.cuff.currentPressure > 0.0
        }
    }
}
