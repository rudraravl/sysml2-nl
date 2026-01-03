package 'Vacuum Bell System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    doc /* 
     * This model describes a Vacuum Bell system used for non-invasive treatment
     * of chest wall deformities. The system creates controlled negative pressure
     * to apply gentle suction force to tissue, promoting gradual tissue expansion
     * and remodeling through sustained vacuum application during treatment sessions.
     */

    attribute def VacuumPressure :> ISQ::PressureValue;
    attribute def BellDiameter :> ISQ::LengthValue;
    attribute def SuctionForce :> ISQ::ForceValue;
    attribute def TreatmentDuration :> ISQ::DurationValue;
    attribute def TissueDisplacement :> ISQ::LengthValue;
    attribute def LeakRate :> ISQ::VolumeFlowRateValue;

    item def VacuumLevel {
        attribute pressure : VacuumPressure;
        attribute timestamp : ISQ::DurationValue;
    }

    item def TreatmentSession {
        attribute duration : TreatmentDuration;
        attribute targetPressure : VacuumPressure;
        attribute achievedDisplacement : TissueDisplacement;
    }

    item def ControlCommand {
        attribute pumpActive : ScalarValues::Boolean;
        attribute valvePosition : ScalarValues::Real;
        attribute targetPressure : VacuumPressure;
    }

    port def VacuumPort {
        attribute currentPressure : VacuumPressure;
        out item vacuumLevel : VacuumLevel;
    }

    port def TissueContactPort {
        attribute contactArea : ISQ::AreaValue;
        attribute appliedForce : SuctionForce;
        out item displacement : TissueDisplacement;
    }

    port def ControlPort {
        in item command : ControlCommand;
        out item status : VacuumLevel;
    }

    part def VacuumPump {
        attribute maxVacuum : VacuumPressure;
        attribute flowCapacity : ISQ::VolumeFlowRateValue;
        attribute powerRating : ISQ::PowerValue;
        port vacuumOutput : VacuumPort;
        port controlInput : ControlPort;

        perform action generateVacuum {
            in targetPressure : VacuumPressure;
            out achievedPressure : VacuumPressure;
        }
    }

    part def PressureRegulator {
        attribute setPoint : VacuumPressure;
        attribute regulationAccuracy : VacuumPressure;
        port vacuumInput : VacuumPort;
        port vacuumOutput : VacuumPort;

        perform action regulatePressure {
            in desiredPressure : VacuumPressure;
            in measuredPressure : VacuumPressure;
            out adjustedPressure : VacuumPressure;
        }
    }

    part def BellChamber {
        attribute diameter : BellDiameter;
        attribute volume : ISQ::VolumeValue;
        attribute sealQuality : ScalarValues::Real;
        port vacuumConnection : VacuumPort;
        port tissueInterface : TissueContactPort;

        perform action applySuction {
            in vacuumPressure : VacuumPressure;
            out suctionForce : SuctionForce;
            out tissueDisplacement : TissueDisplacement;
        }
    }

    part def PressureSensor {
        attribute measurementAccuracy : VacuumPressure;
        attribute responseTime : ISQ::DurationValue;
        attribute calibrationDate : ISQ::DurationValue;
        port sensing : VacuumPort;

        perform action measurePressure {
            out currentPressure : VacuumPressure;
            out reading : VacuumLevel;
        }
    }

    part def SafetyValve {
        attribute releaseThreshold : VacuumPressure;
        attribute responseTime : ISQ::DurationValue;
        port vacuumMonitor : VacuumPort;

        perform action monitorAndRelease {
            in pressure : VacuumPressure;
            out safetyTriggered : ScalarValues::Boolean;
        }
    }

    part def ControlUnit {
        attribute sessionTimer : TreatmentDuration;
        attribute pressureProfile : VacuumPressure[*];
        attribute maxSessionDuration : TreatmentDuration;
        port controlOutput : ControlPort;
        port sensorInput : VacuumPort;

        perform action manageSession {
            in sessionParams : TreatmentSession;
            in currentPressure : VacuumPressure;
            out pumpCommand : ControlCommand;
            out sessionComplete : ScalarValues::Boolean;
        }
    }

    part def ReleaseValve {
        attribute position : ScalarValues::Real;
        port vacuumSide : VacuumPort;

        perform action releaseVacuum {
            in releaseRate : ScalarValues::Real;
            out pressureReleased : ScalarValues::Boolean;
        }
    }

    part def VacuumBellSystem {
        attribute operatingPressure : VacuumPressure;
        attribute bellSize : BellDiameter;
        attribute maxTreatmentTime : TreatmentDuration;
        attribute sessionActive : ScalarValues::Boolean;

        part pump : VacuumPump {
            attribute :>> maxVacuum = -90.0[SI::kPa];
            attribute :>> flowCapacity = 20.0[SI::L/SI::min];
            attribute :>> powerRating = 150.0[SI::W];
        }

        part regulator : PressureRegulator {
            attribute :>> setPoint = -65.0[SI::kPa];
            attribute :>> regulationAccuracy = 1.0[SI::kPa];
        }

        part bell : BellChamber {
            attribute :>> diameter = 160.0[SI::mm];
            attribute :>> volume = 3.2[SI::L];
            attribute :>> sealQuality = 0.97;
        }

        part sensor : PressureSensor {
            attribute :>> measurementAccuracy = 0.5[SI::kPa];
            attribute :>> responseTime = 0.05[SI::s];
        }

        part safetyValve : SafetyValve {
            attribute :>> releaseThreshold = -88.0[SI::kPa];
            attribute :>> responseTime = 0.02[SI::s];
        }

        part controller : ControlUnit {
            attribute :>> sessionTimer = 0.0[SI::s];
            attribute :>> maxSessionDuration = 1800.0[SI::s];
        }

        part releaseValve : ReleaseValve {
            attribute :>> position = 0.0;
        }

        connection pumpToRegulator connect pump.vacuumOutput to regulator.vacuumInput;
        connection regulatorToBell connect regulator.vacuumOutput to bell.vacuumConnection;
        connection sensorToBell connect sensor.sensing to bell.vacuumConnection;
        connection safetyToBell connect safetyValve.vacuumMonitor to bell.vacuumConnection;
        connection sensorToController connect sensor.sensing to controller.sensorInput;
        connection controllerToPump connect controller.controlOutput to pump.controlInput;
        connection releaseToBell connect releaseValve.vacuumSide to bell.vacuumConnection;

        perform action conductTreatmentSession {
            in sessionParameters : TreatmentSession;
            out sessionResult : TreatmentSession;

            first start;
            then action initializeSystem {
                out systemReady : ScalarValues::Boolean;
            }
            then decide;
                if initializeSystem.systemReady then beginTreatment;
                if not initializeSystem.systemReady then abortSession;

            action beginTreatment {
                first merge treatmentCycle;
                then action activatePump : pump.generateVacuum {
                    in targetPressure = sessionParameters.targetPressure;
                    out achievedPressure;
                }
                then action regulate : regulator.regulatePressure {
                    in desiredPressure = sessionParameters.targetPressure;
                    in measuredPressure = sensor.measurePressure.currentPressure;
                    out adjustedPressure;
                }
                then action applySuctionForce : bell.applySuction {
                    in vacuumPressure = regulate.adjustedPressure;
                    out suctionForce;
                    out tissueDisplacement;
                }
                then action checkSafety : safetyValve.monitorAndRelease {
                    in pressure = sensor.measurePressure.currentPressure;
                    out safetyTriggered;
                }
                then action updateSession : controller.manageSession {
                    in sessionParams = sessionParameters;
                    in currentPressure = sensor.measurePressure.currentPressure;
                    out pumpCommand;
                    out sessionComplete;
                }
                then decide;
                    if checkSafety.safetyTriggered then emergencyShutdown;
                    if updateSession.sessionComplete then normalShutdown;
                    if not checkSafety.safetyTriggered and 
                       not updateSession.sessionComplete then treatmentCycle;
            }

            action normalShutdown {
                first start;
                then action gradualRelease : releaseValve.releaseVacuum {
                    in releaseRate = 0.5;
                    out pressureReleased;
                }
                then action recordResults {
                    in displacement = bell.applySuction.tissueDisplacement;
                    in duration = sessionParameters.duration;
                }
                then assign sessionResult := sessionParameters;
                then done;
            }

            action emergencyShutdown {
                first start;
                then action rapidRelease : releaseValve.releaseVacuum {
                    in releaseRate = 1.0;
                    out pressureReleased;
                }
                then done;
            }

            action abortSession;
            then done;
        }
    }

    requirement def SafetyRequirement {
        doc /* Safety requirements for vacuum bell operation. */
    }

    requirement def EffectivenessRequirement {
        doc /* Effectiveness requirements for treatment outcomes. */
    }

    requirement def UsabilityRequirement {
        doc /* Usability requirements for system operation. */
    }

    requirement <'VB-REQ-001'> pressureSafetyLimit : SafetyRequirement {
        doc /* 
         * The vacuum bell system shall not exceed maximum safe vacuum pressure
         * to prevent tissue damage or discomfort.
         */
        subject system : VacuumBellSystem;
        require constraint {
            system.operatingPressure >= -85.0[SI::kPa] and
            system.operatingPressure <= 0.0[SI::kPa]
        }
    }

    requirement <'VB-REQ-002'> pressureStability : EffectivenessRequirement {
        doc /* 
         * The vacuum bell system shall maintain stable vacuum pressure
         * within specified tolerance during treatment.
         */
        subject system : VacuumBellSystem;
        require constraint {
            system.sensor.measurementAccuracy <= 1.0[SI::kPa]
        }
    }

    requirement <'VB-REQ-003'> sealIntegrity : UsabilityRequirement {
        doc /* 
         * The bell chamber shall maintain adequate seal quality
         * to sustain therapeutic vacuum levels.
         */
        subject system : VacuumBellSystem;
        require constraint {
            system.bell.sealQuality >= 0.95
        }
    }

    requirement <'VB-REQ-004'> sessionDurationLimit : SafetyRequirement {
        doc /* 
         * The system shall limit treatment session duration
         * to prevent excessive tissue stress.
         */
        subject system : VacuumBellSystem;
        require constraint {
            system.maxTreatmentTime <= 1800.0[SI::s]
        }
    }

    requirement <'VB-REQ-005'> primaryFunction {
        doc /* 
         * The vacuum bell system shall create and maintain controlled negative
         * pressure to apply gentle, sustained suction force to chest wall tissue,
         * promoting gradual tissue expansion and remodeling through repeated
         * treatment sessions for non-invasive correction of chest wall deformities.
         */
        subject system : VacuumBellSystem;

        assume constraint validBellSize {
            system.bellSize >= 100.0[SI::mm] and
            system.bellSize <= 200.0[SI::mm]
        }

        require pressureSafetyLimit;
        require pressureStability;
        require sealIntegrity;
        require sessionDurationLimit;
    }
}
