package BIADSystem {

    // ===== Value Types =====
    value type Volume { unit "mL"; }
    value type Pressure { unit "cmH2O"; }
    value type Length { unit "mm"; }
    value type Mass { unit "kg"; }
    value type Percentage { unit "%"; }
    value type Frequency { unit "1/min"; }
    value type FlowRate { unit "L/min"; }
    value type Concentration { unit "%"; }
    value type Duration { unit "s"; }

    // ===== Item Types =====
    item def Air;
    item def Oxygen;
    item def CarbonDioxide;
    item def StomachContents;
    item def AirOxygenMixture {
        attribute oxygenConcentration: Concentration = 100 [%];
        attribute carbonDioxideFraction: Percentage = 0 [%];
    }

    // ===== Port Definitions =====
    port def GasFlowPort {
        out item deliveredGas: AirOxygenMixture;
        in item exhaledGas: AirOxygenMixture;
    }

    port def InflationPort {
        out item inflationAir: Air;
    }

    port def PressurePort {
        out pressureReading: Pressure;
    }

    port def MonitoringPort {
        in item sampledGas: AirOxygenMixture;
        out spo2Value: Percentage;
        out etco2Value: Percentage;
    }

    // ===== Requirements =====
    requirement def SealPharynx {
        subject cuff: Cuff;
        doc /* The pharyngeal cuff shall seal the upper pharynx when inflated. */
        constraint { cuff.pressure >= 40 [cmH2O] and cuff.pressure <= 60 [cmH2O] }
    }

    requirement def BlockEsophagus {
        subject cuff: Cuff;
        doc /* The esophageal cuff shall block the esophagus entrance when inflated. */
        constraint { cuff.pressure >= 25 [cmH2O] and cuff.pressure <= 40 [cmH2O] }
    }

    requirement def PreventAspiration {
        doc /* The system shall prevent aspiration of stomach contents into the lungs. */
        constraint { airwayTube.esophagealCuff.pressure >= 25 [cmH2O] }
    }

    requirement def DeliverVentilation {
        subject bag: ManualVentilationBag;
        doc /* The system shall deliver effective ventilation to the patient. */
        constraint { bag.ventilationRate >= 10 [1/min] and bag.ventilationRate <= 12 [1/min] }
        constraint { bag.tidalVolume >= 500 [mL] and bag.tidalVolume <= 700 [mL] }
    }

    requirement def ConfirmPlacement {
        subject monitor: PatientMonitor;
        doc /* The system shall confirm correct tube placement via EtCO2 monitoring. */
        constraint { monitor.etco2 >= 4 [%] and monitor.etco2 <= 6 [%] }
    }

    requirement def MaintainOxygenation {
        subject monitor: PatientMonitor;
        doc /* The system shall maintain patient oxygen saturation above 90%. */
        constraint { monitor.spo2 >= 90 [%] }
    }

    // ===== Cuff =====
    part def Cuff {
        attribute maxVolume: Volume;
        attribute maxSafePressure: Pressure;
        attribute minSealPressure: Pressure;
        attribute volume: Volume = 0 [mL];
        attribute pressure: Pressure = 0 [cmH2O];
        attribute inflated: Boolean = false;
        port inflationPort: InflationPort;
        port pressurePort: PressurePort;

        action inflate {
            in targetVolume: Volume;
            then assign volume := targetVolume;
            then assign pressure := (volume / maxVolume) * maxSafePressure;
            then assign inflated := true;
        }

        action deflate {
            then assign volume := 0 [mL];
            then assign pressure := 0 [cmH2O];
            then assign inflated := false;
        }
    }

    // ===== Airway Tube =====
    part def AirwayTube {
        attribute tubeSize: Length = 100 [mm];
        attribute tubeDiameter: Length = 14 [mm];
        attribute insertionDepth: Length = 220 [mm];
        attribute inserted: Boolean = false;
        port externalPort: GasFlowPort;
        port distalPort: GasFlowPort;

        part pharyngealCuff: Cuff {
            redefines maxVolume = 85 [mL];
            redefines maxSafePressure = 60 [cmH2O];
            redefines minSealPressure = 40 [cmH2O];
        }
        part esophagealCuff: Cuff {
            redefines maxVolume = 15 [mL];
            redefines maxSafePressure = 40 [cmH2O];
            redefines minSealPressure = 25 [cmH2O];
        }

        action insert {
            then assign inserted := true;
        }

        action remove {
            then pharyngealCuff.deflate();
            then esophagealCuff.deflate();
            then assign inserted := false;
        }

        satisfy SealPharynx by pharyngealCuff;
        satisfy BlockEsophagus by esophagealCuff;
    }

    // ===== Inflation Syringe =====
    part def InflationSyringe {
        attribute capacity: Volume = 100 [mL];
        attribute currentVolume: Volume = 100 [mL];
        port outputPort: InflationPort;

        action deliverAir {
            in targetVolume: Volume;
            then assign currentVolume := currentVolume - targetVolume;
        }
    }

    // ===== Pressure Manometer =====
    part def PressureManometer {
        attribute safePressureMax: Pressure = 60 [cmH2O];
        attribute warningPressure: Pressure = 50 [cmH2O];
        attribute currentReading: Pressure = 0 [cmH2O];
        attribute alarmActive: Boolean = false;
        port inputPort: PressurePort;

        action measurePressure {
            in pressure: Pressure;
            then assign currentReading := pressure;
            then assign alarmActive := (pressure > safePressureMax);
        }
    }

    // ===== Manual Ventilation Bag =====
    part def ManualVentilationBag {
        attribute bagVolume: Volume = 1600 [mL];
        attribute tidalVolume: Volume = 600 [mL];
        attribute ventilationRate: Frequency = 12 [1/min];
        attribute oxygenConcentration: Concentration = 100 [%];
        attribute squeezeCount: Integer = 0;
        port patientPort: GasFlowPort;
        port oxygenPort: GasFlowPort;

        action squeeze {
            in gas: AirOxygenMixture;
            out deliveredVolume: Volume;
            then assign deliveredVolume := tidalVolume;
            then assign squeezeCount := squeezeCount + 1;
        }

        action attachOxygen {
            then assign oxygenConcentration := 100 [%];
        }

        satisfy DeliverVentilation;
    }

    // ===== Oxygen Source =====
    part def OxygenSource {
        attribute flowRate: FlowRate = 15 [L/min];
        attribute concentration: Concentration = 100 [%];
        attribute tankLevel: Percentage = 100 [%];
        port outputPort: GasFlowPort;

        action supplyOxygen {
            out oxygen: Oxygen;
            then assign tankLevel := tankLevel - 1 [%];
        }
    }

    // ===== Patient Monitor =====
    part def PatientMonitor {
        attribute spo2: Percentage = 98 [%];
        attribute etco2: Percentage = 5 [%];
        attribute respiratoryRate: Frequency = 12 [1/min];
        attribute alarmThresholdLowSpo2: Percentage = 90 [%];
        attribute alarmThresholdLowEtco2: Percentage = 4 [%];
        attribute alarmActive: Boolean = false;
        port monitoringPort: MonitoringPort;

        action monitorPatient {
            in exhaledGas: AirOxygenMixture;
            out spo2Reading: Percentage;
            out etco2Reading: Percentage;
            then assign spo2Reading := spo2;
            then assign etco2Reading := etco2;
            then assign alarmActive := (spo2 < alarmThresholdLowSpo2) or (etco2 < alarmThresholdLowEtco2);
        }

        satisfy ConfirmPlacement;
        satisfy MaintainOxygenation;
    }

    // ===== Patient =====
    part def Patient {
        attribute weight: Mass = 70 [kg];
        attribute age: Integer = 40;
        attribute lungCompliance: Real = 50;
        attribute airwayPatent: Boolean = false;
        attribute ventilated: Boolean = false;
        port airwayPort: GasFlowPort;
        port esophagusPort: GasFlowPort;

        action receiveVentilation {
            in gas: AirOxygenMixture;
            in volume: Volume;
            then assign ventilated := true;
        }

        action exhale {
            out exhaledGas: AirOxygenMixture;
        }
    }

    // ===== BIAD System =====
    part def BIADSystem {
        attribute systemReady: Boolean = false;
        attribute operatorReady: Boolean = false;
        attribute tubeInserted: Boolean = false;
        attribute cuffsInflated: Boolean = false;
        attribute placementConfirmed: Boolean = false;
        attribute ventilationStable: Boolean = false;
        attribute breathNeeded: Boolean = true;
        attribute patientStable: Boolean = false;

        part airwayTube: AirwayTube;
        part inflationSyringe: InflationSyringe;
        part pressureManometer: PressureManometer;
        part ventilationBag: ManualVentilationBag;
        part oxygenSource: OxygenSource;
        part patientMonitor: PatientMonitor;
        part patient: Patient;

        // Connections
        connection syringeToPharyngealCuff
            connect inflationSyringe.outputPort to airwayTube.pharyngealCuff.inflationPort;
        connection syringeToEsophagealCuff
            connect inflationSyringe.outputPort to airwayTube.esophagealCuff.inflationPort;
        connection pharyngealCuffToManometer
            connect airwayTube.pharyngealCuff.pressurePort to pressureManometer.inputPort;
        connection esophagealCuffToManometer
            connect airwayTube.esophagealCuff.pressurePort to pressureManometer.inputPort;
        connection oxygenToBag
            connect oxygenSource.outputPort to ventilationBag.oxygenPort;
        connection bagToTube
            connect ventilationBag.patientPort to airwayTube.externalPort;
        connection tubeToPatient
            connect airwayTube.distalPort to patient.airwayPort;
        connection patientToMonitor
            connect patient.airwayPort to patientMonitor.monitoringPort;

        satisfy PreventAspiration;
        satisfy DeliverVentilation by ventilationBag;
        satisfy ConfirmPlacement by patientMonitor;
        satisfy MaintainOxygenation by patientMonitor;

        // ===== Operational Lifecycle State Machine =====
        state def OperationalLifecycle {
            entry action { systemReady := true; }

            state Standby {
                entry action { /* Device inspected and prepared for deployment */ }
                do action { oxygenSource.supplyOxygen(); }
            }

            state Inserting {
                entry action {
                    airwayTube.insert();
                    assign tubeInserted := true;
                }
            }

            state Inflating {
                entry action {
                    inflationSyringe.deliverAir(targetVolume = 85 [mL]);
                    airwayTube.pharyngealCuff.inflate(targetVolume = 85 [mL]);
                    inflationSyringe.deliverAir(targetVolume = 15 [mL]);
                    airwayTube.esophagealCuff.inflate(targetVolume = 15 [mL]);
                    pressureManometer.measurePressure(pressure = airwayTube.pharyngealCuff.pressure);
                    pressureManometer.measurePressure(pressure = airwayTube.esophagealCuff.pressure);
                    assign cuffsInflated := true;
                }
            }

            state VerifyingPlacement {
                entry action {
                    patient.exhale();
                    patientMonitor.monitorPatient(exhaledGas = AirOxygenMixture);
                    assign placementConfirmed := (patientMonitor.etco2 >= 4 [%]);
                }
            }

            state Ventilating {
                entry action {
                    ventilationBag.attachOxygen();
                    ventilationBag.squeeze(gas = AirOxygenMixture);
                    patient.receiveVentilation(gas = AirOxygenMixture, volume = ventilationBag.tidalVolume);
                }
                do action {
                    ventilationBag.squeeze(gas = AirOxygenMixture);
                    patient.receiveVentilation(gas = AirOxygenMixture, volume = ventilationBag.tidalVolume);
                }
            }

            state Monitoring {
                entry action {
                    patient.exhale();
                    patientMonitor.monitorPatient(exhaledGas = AirOxygenMixture);
                    assign ventilationStable := (patientMonitor.spo2 >= 90 [%]) and (patientMonitor.etco2 >= 4 [%]);
                }
                do action {
                    patientMonitor.monitorPatient(exhaledGas = AirOxygenMixture);
                }
            }

            state Removed {
                entry action {
                    airwayTube.remove();
                    assign patientStable := true;
                }
            }

            transition Standby -> Inserting
                when operatorReady
                doc /* Operator initiates insertion when ready. */;

            transition Inserting -> Inflating
                when tubeInserted
                doc /* Tube fully inserted; begin cuff inflation. */
