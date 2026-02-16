package VentilatorAssociatedLungInjurySystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    doc /* This model describes a protective mechanical ventilation system designed to 
         * prevent Ventilator-Associated Lung Injury (VALI). The system monitors and controls
         * airway pressures and tidal volumes to maintain lung-protective ventilation parameters
         * while providing adequate gas exchange support to critically ill patients. */

    attribute def AirwayPressureValue :> PressureValue;
    attribute def TidalVolumeValue :> VolumeValue;
    attribute def RespiratoryRateValue :> FrequencyValue;
    attribute def FlowRateValue :> VolumeFlowRateValue;
    attribute def OxygenConcentrationValue :> Real;
    attribute def PredictedBodyWeightValue :> MassValue;

    item def VentilationParameters {
        attribute peakInspiratoryPressure : AirwayPressureValue;
        attribute plateauPressure : AirwayPressureValue;
        attribute positiveEndExpiratoryPressure : AirwayPressureValue;
        attribute tidalVolume : TidalVolumeValue;
        attribute respiratoryRate : RespiratoryRateValue;
        attribute inspiratoryFlow : FlowRateValue;
        attribute fio2 : OxygenConcentrationValue;
    }

    item def PatientData {
        attribute predictedBodyWeight : PredictedBodyWeightValue;
        attribute currentPressure : AirwayPressureValue;
        attribute deliveredVolume : TidalVolumeValue;
        attribute compliance : Real;
    }

    item def AlarmSignal {
        attribute highPressureAlarm : Boolean;
        attribute highVolumeAlarm : Boolean;
        attribute lowPressureAlarm : Boolean;
        attribute apneaAlarm : Boolean;
    }

    port def PneumaticPort {
        out gasFlow : FlowRateValue;
        out pressure : AirwayPressureValue;
    }

    port def SensorPort {
        in measuredPressure : AirwayPressureValue;
        in measuredVolume : TidalVolumeValue;
        in measuredFlow : FlowRateValue;
    }

    port def ControlInterfacePort {
        in ventilationSettings : VentilationParameters;
        out alarms : AlarmSignal;
        out monitoredData : PatientData;
    }

    port def PatientInterfacePort {
        out airwayOut;
        in airwayIn;
    }

    part def PneumaticDeliverySystem {
        attribute maxFlowCapacity : FlowRateValue;
        attribute pressureReservoir : AirwayPressureValue;
        
        port gasOutput : PneumaticPort;
        port controlInput;

        action deliverInspiratoryFlow {
            in targetFlow : FlowRateValue;
            in targetPressure : AirwayPressureValue;
            out actualFlow : FlowRateValue;
        }

        action maintainPEEP {
            in peepLevel : AirwayPressureValue;
        }

        action releaseExhalation;
    }

    part def SensorArray {
        port pressureSensor : SensorPort;
        port flowSensor : SensorPort;
        port volumeSensor : SensorPort;
        port patientConnection : PatientInterfacePort;

        action measureAirwayPressure {
            out pressure : AirwayPressureValue;
        }

        action measureTidalVolume {
            out volume : TidalVolumeValue;
        }

        action measureFlowRate {
            out flow : FlowRateValue;
        }
    }

    part def VentilatorController {
        attribute pipLimit : AirwayPressureValue = 3000 [Pa];
        attribute plateauPressureLimit : AirwayPressureValue = 2940 [Pa];
        attribute maxTidalVolumePerKg : Real = 6.0e-6;
        attribute minTidalVolumePerKg : Real = 4.0e-6;
        attribute targetPEEP : AirwayPressureValue = 500 [Pa];
        attribute targetRR : RespiratoryRateValue = 0.2 [Hz];

        port sensorInput : SensorPort;
        port userInterface : ControlInterfacePort;
        port pneumaticControl;

        in patientPBW : PredictedBodyWeightValue;

        action def ProtectiveVentilationControl {
            first start;
            then action initializeParameters {
                out settings : VentilationParameters;
            }
            then merge standbyLoop;
            then decide;
                if userInterface.ventilationSettings then activeVentilation;
                else standbyLoop;
            action activeVentilation {
                first action beginInspiration {
                    in targetVolume : TidalVolumeValue;
                    in pressureLimit : AirwayPressureValue;
                }
                then action evaluatePressure {
                    in currentPressure : AirwayPressureValue;
                    in limit : AirwayPressureValue;
                }
                then decide;
                    if sensorInput.measuredPressure > pipLimit then activatePressureAlarm;
                    else measurePlateauPressure;
                action measurePlateauPressure {
                    out pPlat : AirwayPressureValue;
                }
                then action evaluatePlateauPressure {
                    in measuredPlateau : AirwayPressureValue;
                }
                then decide;
                    if measuredPlateau > plateauPressureLimit then activatePlateauAlarm;
                    else beginExpiration;
                action beginExpiration {
                    in peepLevel : AirwayPressureValue;
                }
                then action evaluateVolume {
                    in deliveredVolume : TidalVolumeValue;
                    in maxVolume : TidalVolumeValue;
                }
                then decide;
                    if sensorInput.measuredVolume > patientPBW * maxTidalVolumePerKg then activateVolumeAlarm;
                    else standbyLoop;
                action activatePressureAlarm {
                    out alarm : AlarmSignal;
                }
                then standbyLoop;
                action activatePlateauAlarm {
                    out alarm : AlarmSignal;
                }
                then standbyLoop;
                action activateVolumeAlarm {
                    out alarm : AlarmSignal;
                }
                then standbyLoop;
            }
            then standbyLoop;
        }
    }

    part def PatientLungModel {
        attribute pbw : PredictedBodyWeightValue;
        attribute lungCompliance : Real;
        attribute airwayResistance : Real;
        attribute currentPressure : AirwayPressureValue;
        attribute currentVolume : TidalVolumeValue;

        port airwayConnection : PatientInterfacePort;
    }

    part def ProtectiveVentilatorSystem {
        attribute patientPredictedBodyWeight : PredictedBodyWeightValue = 70 [kg];

        part pneumatics : PneumaticDeliverySystem {
            attribute maxFlowCapacity = 0.002 [m^3/s];
            attribute pressureReservoir = 5000 [Pa];
        }

        part sensors : SensorArray;

        part controller : VentilatorController {
            in patientPBW = patientPredictedBodyWeight;
        }

        part patient : PatientLungModel {
            attribute pbw = patientPredictedBodyWeight;
            attribute lungCompliance = 0.00005;
            attribute airwayResistance = 500.0;
        }

        port userPanel : ControlInterfacePort;
        port patientCircuit : PatientInterfacePort;

        connect pneumatics.gasOutput to sensors.pressureSensor;
        connect sensors.patientConnection to patient.airwayConnection;
        connect sensors.pressureSensor to controller.sensorInput;
        connect controller.pneumaticControl to pneumatics.controlInput;
        connect controller.userInterface to userPanel;
        connect patient.airwayConnection to patientCircuit;
    }

    requirement <'VALI-GOAL-001'> preventVentilatorAssociatedLungInjury {
        doc /* The protective ventilator system shall minimize the risk of 
             * ventilator-associated lung injury by controlling airway pressures
             * and tidal volumes within lung-protective ranges while maintaining
             * adequate gas exchange for critically ill patients. */
        subject system : ProtectiveVentilatorSystem;
    }

    requirement <'VALI-SYS-001'> limitPeakInspiratoryPressure {
        doc /* The system shall limit peak inspiratory pressure (PIP) to 
             * no more than 30 cmH2O (approximately 3000 Pa) to prevent 
             * barotrauma and volutrauma. */
        subject system : ProtectiveVentilatorSystem;
        in pip : AirwayPressureValue;
        assert constraint {
            pip <= 3000 [Pa]
        }
    }

    requirement <'VALI-SYS-002'> limitPlateauPressure {
        doc /* The system shall limit plateau pressure (Pplat) to no more 
             * than 30 cmH2O (approximately 2940 Pa) to minimize alveolar 
             * overdistension and reduce risk of barotrauma. */
        subject system : ProtectiveVentilatorSystem;
        in pPlat : AirwayPressureValue;
        assert constraint {
            pPlat <= 2940 [Pa]
        }
    }

    requirement <'VALI-SYS-003'> limitTidalVolume {
        doc /* The system shall limit tidal volume to 4-6 mL/kg of predicted 
             * body weight to prevent volutrauma and reduce inflammatory response. */
        subject system : ProtectiveVentilatorSystem;
        in vt : TidalVolumeValue;
        in pbw : PredictedBodyWeightValue = system.patientPredictedBodyWeight;
        assert constraint {
            vt >= pbw * 4.0e-6 [m^3/kg] and vt <= pbw * 6.0e-6 [m^3/kg]
        }
    }

    requirement <'VALI-SYS-004'> maintainPositivePressure {
        doc /* The system shall maintain positive end-expiratory pressure (PEEP)
             * to prevent alveolar collapse and atelectrauma while avoiding 
             * excessive pressure that could cause overdistension. */
        subject system : ProtectiveVentilatorSystem;
        in peep : AirwayPressureValue;
        assert constraint {
            peep >= 500 [Pa] and peep <= 1500 [Pa]
        }
    }

    requirement <'VALI-SYS-005'> limitDrivingPressure {
        doc /* The system shall limit driving pressure (Pplat - PEEP) to 
             * no more than 15 cmH2O (approximately 1470 Pa) to minimize 
             * cyclic alveolar stress and strain. */
        subject system : ProtectiveVentilatorSystem;
        in pPlat : AirwayPressureValue;
        in peep : AirwayPressureValue;
        let drivingPressure = pPlat - peep;
        assert constraint {
            drivingPressure <= 1470 [Pa]
        }
    }

    requirement <'VALI-SYS-006'> provideAlarmSystem {
        doc /* The system shall provide immediate alarms when pressure or 
             * volume limits are exceeded and automatically adjust ventilation
             * parameters to return to safe operating ranges. */
        subject system : ProtectiveVentilatorSystem;
    }

    satisfy preventVentilatorAssociatedLungInjury by ProtectiveVentilatorSystem;
}
