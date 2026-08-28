package MedicalGasDeliverySystem {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value def PressureValue :> Real {
        unit psi;
    }
    value def FlowRateValue :> Real {
        unit 'L/min';
    }
    value def VolumeValue :> Real {
        unit L;
    }
    value def TemperatureValue :> Real {
        unit degC;
    }

    // ===== Item Types =====
    item def MedicalOxygen {
        attribute purity : Real = 0.995; // 99.5% medical grade
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }

    item def AlarmSignal {
        attribute severity : SeverityKind;
        attribute message : String;
    }

    enum def SeverityKind { info; warning; critical; }

    // ===== Port Definitions =====
    port def OxygenOutPort {
        out oxygen : MedicalOxygen;
        attribute pressure : PressureValue;
    }

    port def OxygenInPort {
        in oxygen : MedicalOxygen;
        attribute pressure : PressureValue;
    }

    port def ControlOutPort {
        out signal : AlarmSignal;
    }

    port def ControlInPort {
        in signal : AlarmSignal;
    }

    port def PressureSensorPort {
        out pressureReading : PressureValue;
    }

    // ===== Requirements =====
    requirement def ContinuousSupplyRequirement {
        doc /* The system shall provide a continuous supply of medical oxygen to all patient care areas without interruption. */
        attribute maxInterruptionDuration : TimeValue = 0 [s];
        satisfy requirement by MedicalGasDeliverySystem.continuity;
    }

    requirement def RedundantBankRequirement {
        doc /* The system shall include a primary and a secondary cylinder bank to ensure redundancy. */
        subject primaryBank : CylinderBank;
        subject secondaryBank : CylinderBank;
        constraint { primaryBank != secondaryBank }
    }

    requirement def AutomaticSwitchoverRequirement {
        doc /* The manifold controller shall automatically switch from primary to secondary bank when primary pressure drops below threshold. */
        attribute switchoverThreshold : PressureValue = 200 [psi];
        constraint { primaryBank.pressure < switchoverThreshold implies activeBank == secondaryBank }
    }

    requirement def PressureRegulationRequirement {
        doc /* The pressure regulator shall reduce cylinder pressure to standardized pipeline pressure. */
        attribute pipelinePressure : PressureValue = 50 [psi];
        attribute tolerance : PressureValue = 5 [psi];
        constraint { abs(regulator.outletPressure - pipelinePressure) <= tolerance }
    }

    requirement def AlarmRequirement {
        doc /* The alarm panel shall alert staff on switchover and critical low secondary pressure. */
        attribute criticalSecondaryThreshold : PressureValue = 150 [psi];
    }

    // ===== Cylinder Bank =====
    part def CylinderBank {
        attribute bankId : String;
        attribute isPrimary : Boolean;
        attribute nominalCapacity : VolumeValue = 50 [L];
        attribute maxPressure : PressureValue = 2200 [psi];
        attribute pressure : PressureValue = maxPressure;
        attribute isActive : Boolean = false;
        attribute isEmpty : Boolean = false;

        port oxygenOut : OxygenOutPort {
            attribute pressure = CylinderBank.this.pressure;
        }
        port pressureSensor : PressureSensorPort;

        action def discharge :> Action {
            in decRate : FlowRateValue = 10 ['L/min'];
            out remainingPressure : PressureValue;
            do {
                if pressure > 0 [psi] {
                    pressure := pressure - (decRate * 1 [min] / nominalCapacity) * maxPressure;
                }
                if pressure <= 0 [psi] {
                    isEmpty := true;
                    pressure := 0 [psi];
                }
                remainingPressure := pressure;
            }
        }

        state def BankStatus {
            entry; then Full;
            state Full;
            state InUse;
            state Low;
            state Empty;
            transition full_to_inUse from Full to InUse when isActive;
            transition inUse_to_low from InUse to Low when pressure < 300 [psi];
            transition low_to_empty from Low to Empty when isEmpty;
        }
    }

    // ===== Manifold Controller =====
    part def ManifoldController {
        attribute switchoverThreshold : PressureValue = 200 [psi];
        attribute criticalSecondaryThreshold : PressureValue = 150 [psi];
        attribute activeBankId : String;
        attribute switchoverCount : Integer = 0;

        port primaryPressureIn : PressureSensorPort;
        port secondaryPressureIn : PressureSensorPort;
        port controlOut : ControlOutPort;
        port oxygenOut : OxygenOutPort;

        action def monitorPressure :> Action {
            in primaryP : PressureValue;
            in secondaryP : PressureValue;
            out switchNeeded : Boolean;
            out criticalAlarm : Boolean;
            do {
                switchNeeded := (primaryP < switchoverThreshold);
                criticalAlarm := (secondaryP < criticalSecondaryThreshold);
            }
        }

        action def performSwitchover :> Action {
            in fromBank : CylinderBank;
            in toBank : CylinderBank;
            do {
                fromBank.isActive := false;
                toBank.isActive := true;
                activeBankId := toBank.bankId;
                switchoverCount := switchoverCount + 1;
            }
        }

        state def ControllerOperation {
            entry; then MonitoringPrimary;
            state MonitoringPrimary {
                entry { activeBankId := "Primary"; }
            }
            state SwitchoverInProgress;
            state MonitoringSecondary {
                entry { activeBankId := "Secondary"; }
            }
            state EmergencyState;

            transition primary_to_switchover
                from MonitoringPrimary to SwitchoverInProgress
                when primaryPressureIn.pressureReading < switchoverThreshold;

            transition switchover_to_secondary
                from SwitchoverInProgress to MonitoringSecondary
                when secondaryPressureIn.pressureReading > switchoverThreshold;

            transition secondary_to_emergency
                from MonitoringSecondary to EmergencyState
                when secondaryPressureIn.pressureReading < criticalSecondaryThreshold;
        }
    }

    // ===== Pressure Regulator =====
    part def PressureRegulator {
        attribute inletPressure : PressureValue;
        attribute outletPressure : PressureValue = 50 [psi];
        attribute targetPressure : PressureValue = 50 [psi];
        attribute regulationAccuracy : PressureValue = 2 [psi];

        port oxygenIn : OxygenInPort;
        port oxygenOut : OxygenOutPort {
            attribute pressure = PressureRegulator.this.outletPressure;
        }

        action def regulate :> Action {
            in inputPressure : PressureValue;
            out outputPressure : PressureValue;
            do {
                inletPressure := inputPressure;
                if inputPressure > targetPressure {
                    outletPressure := targetPressure;
                } else {
                    outletPressure := inputPressure;
                }
                outputPressure := outletPressure;
            }
        }
    }

    // ===== Distribution Pipeline =====
    part def DistributionPipeline {
        attribute totalLength : Real = 500 [m];
        attribute material : String = "Copper (medical grade)";
        attribute internalDiameter : Real = 0.025 [m];
        attribute pipelinePressure : PressureValue;

        port oxygenIn : OxygenInPort;
        port oxygenOut : OxygenOutPort {
            attribute pressure = DistributionPipeline.this.pipelinePressure;
        }

        action def transport :> Action {
            in inputPressure : PressureValue;
            in flowRate : FlowRateValue;
            out outputPressure : PressureValue;
            do {
                // Pressure drop due to friction (simplified)
                pipelinePressure := inputPressure - 1 [psi];
                outputPressure := pipelinePressure;
            }
        }
    }

    // ===== Outlet Terminal =====
    part def OutletTerminal {
        attribute terminalId : String;
        attribute location : String;
        attribute isOccupied : Boolean = false;
        attribute currentFlowRate : FlowRateValue = 0 ['L/min'];
        attribute maxFlowRate : FlowRateValue = 15 ['L/min'];

        port oxygenIn : OxygenInPort;

        action def deliverOxygen :> Action {
            in requestedFlow : FlowRateValue;
            out deliveredFlow : FlowRateValue;
            do {
                if requestedFlow <= maxFlowRate {
                    currentFlowRate := requestedFlow;
                } else {
                    currentFlowRate := maxFlowRate;
                }
                deliveredFlow := currentFlowRate;
            }
        }
    }

    // ===== Alarm Panel =====
    part def AlarmPanel {
        attribute panelId : String = "AP-001";
        attribute location : String = "Nurses Station";
        attribute activeAlarms : Integer = 0;
        attribute lastAlarmTime : TimeValue;

        port controlIn : ControlInPort;
        port audibleOut;
        port visualOut;

        action def raiseAlarm :> Action {
            in signal : AlarmSignal;
            do {
                activeAlarms := activeAlarms + 1;
                if signal.severity == SeverityKind::critical {
                    // Trigger audible and visual critical alarm
                } elif signal.severity == SeverityKind::warning {
                    // Trigger visual warning
                }
            }
        }

        action def acknowledgeAlarm :> Action {
            do {
                if activeAlarms > 0 {
                    activeAlarms := activeAlarms - 1;
                }
            }
        }

        state def AlarmPanelState {
            entry; then Normal;
            state Normal {
                entry { activeAlarms := 0; }
            }
            state WarningActive;
            state CriticalActive;
            transition normal_to_warning from Normal to WarningActive
                when controlIn.signal.severity == SeverityKind::warning;
            transition normal_to_critical from Normal to CriticalActive
                when controlIn.signal.severity == SeverityKind::critical;
            transition warning_to_critical from WarningActive to CriticalActive
                when controlIn.signal.severity == SeverityKind::critical;
            transition critical_to_warning from CriticalActive to WarningActive
                when activeAlarms == 0;
            transition warning_to_normal from WarningActive to Normal
                when activeAlarms == 0;
        }
    }

    // ===== Patient Care Area =====
    part def PatientCareArea {
        attribute areaId : String;
        attribute areaType : CareAreaType;
        attribute numberOfBeds : Integer;

        part outlets : OutletTerminal[*] {
            attribute location = PatientCareArea.this.areaId;
        }

        port oxygenIn : OxygenInPort;
    }

    enum def CareAreaType { operatingRoom; icu; emergencyRoom; generalWard; }

    // ===== Top-Level System =====
    part def MedicalGasDeliverySystem {
        attribute systemId : String = "MGDS-001";
        attribute facilityName : String = "General Hospital";
        attribute installationDate : String = "2024-01-15";

        // Requirements satisfaction
        satisfy ContinuousSupplyRequirement;
        satisfy RedundantBankRequirement {
            subject primaryBank = primaryBank;
            subject secondaryBank = secondaryBank;
        }
        satisfy AutomaticSwitchoverRequirement;
        satisfy PressureRegulationRequirement;
        satisfy AlarmRequirement;

        part primaryBank : CylinderBank {
            attribute bankId = "Primary-Bank-A";
            attribute isPrimary = true;
            attribute pressure = 2200 [psi];
            attribute isActive = true;
        }

        part secondaryBank : CylinderBank {
            attribute bankId = "Secondary-Bank-B";
            attribute isPrimary = false;
            attribute pressure = 2200 [psi];
            attribute isActive = false;
        }

        part manifoldController : ManifoldController {
            attribute activeBankId = "Primary-Bank-A";
        }

        part pressureRegulator : PressureRegulator;
        part distributionPipeline : DistributionPipeline;

        part careAreas : PatientCareArea[*] {
            part operatingRoom1 :> PatientCareArea {
                attribute areaId = "OR-1";
                attribute areaType = CareAreaType::operatingRoom;
                attribute numberOfBeds = 1;
                part outlets : OutletTerminal[4] {
                    attribute terminalId = "OR1-OT" + (index + 1);
                }
            }
            part icu1 :> PatientCareArea {
                attribute areaId = "ICU-1";
                attribute areaType = CareAreaType::icu;
                attribute numberOfBeds = 12;
                part outlets : OutletTerminal[12] {
                    attribute terminalId = "ICU1-OT" + (index + 1);
                }
            }
            part emergencyRoom1 :> PatientCareArea {
                attribute areaId = "ER-1";
                attribute areaType = CareAreaType::emergencyRoom;
                attribute numberOfBeds = 8;
                part outlets : OutletTerminal[8] {
                    attribute terminalId = "ER1-OT" + (index + 1);
                }
            }
        }

        part alarmPanel : AlarmPanel;

        // ===== Connections =====
        connection primaryBankToController connect primaryBank.oxygenOut to manifoldController.oxygenOut;
        connection secondaryBankToController connect secondaryBank.oxygenOut to manifoldController.oxygenOut;
        connection primaryPressureSense connect primaryBank.pressureSensor to manifoldController.primaryPressureIn;
        connection secondaryPressureSense connect secondaryBank.pressureSensor to manifoldController.secondaryPressureIn;
        connection controllerToRegulator connect manifoldController.oxygenOut to pressureRegulator.oxygenIn;
        connection regulatorToPipeline connect pressureRegulator.oxygenOut to distributionPipeline.oxygenIn;
        connection pipelineToCareAreas connect distributionPipeline.oxygenOut to careAreas.oxygenIn;
        connection controllerToAlarm connect manifoldController.controlOut to alarmPanel.controlIn;

        // ===== System Behavior =====
        action def systemOperation :> Action {
            do {
                // Monitor primary bank pressure
                if primaryBank.pressure < manifoldController.switchoverThreshold {
                    // Perform switchover
                    primaryBank.isActive := false;
                    secondaryBank.isActive := true;
                    manifoldController.activeBankId := secondaryBank.bankId;
                    manifoldController.switchoverCount := manifoldController.switchoverCount + 1;
                    // Raise warning alarm
                    alarmPanel.raiseAlarm(
                        signal = AlarmSignal {
                            severity = SeverityKind::warning;
                            message = "Switchover to secondary bank. Replace primary cylinders.";
                        }
                    );
                }
                // Check secondary bank critical level
                if secondaryBank.pressure < manifoldController.criticalSecondaryThreshold {
                    alarmPanel.raiseAlarm(
                        signal = AlarmSignal {
                            severity = SeverityKind::critical;
                            message = "Secondary bank critically low. Immediate action required.";
                        }
                    );
                }
                // Regulate pressure
                pressureRegulator.regulate(
                    inputPressure = (if primaryBank.isActive then primaryBank.pressure else secondaryBank.pressure)
                );
                // Transport through pipeline
                distributionPipeline.transport(
                    inputPressure = pressureRegulator.outletPressure,
                    flowRate = 50 ['L/min']
                );
            }
        }

        state def SystemOperatingMode {
            entry; then NormalOperation;
            state NormalOperation {
                entry { primaryBank.isActive := true; secondaryBank.isActive := false; }
            }
            state BackupOperation {
                entry { primaryBank.isActive := false; secondaryBank.isActive := true; }
            }
            state EmergencyOperation;
            state MaintenanceMode;

            transition normal_to_backup from NormalOperation to BackupOperation
                when primaryBank.pressure < manifoldController.switchoverThreshold;
            transition backup_to_emergency from BackupOperation to EmergencyOperation
                when secondaryBank.pressure < manifoldController.criticalSecondaryThreshold;
            transition any_to_maintenance from NormalOperation to MaintenanceMode
                when maintenanceRequested;
            transition maintenance_to_normal from MaintenanceMode to NormalOperation
                when maintenanceComplete;
        }

        attribute maintenanceRequested : Boolean = false;
        attribute maintenanceComplete : Boolean = false;

        // Continuity verification
        assertion continuity {
            doc /* No interruption in oxygen supply during switchover. */
            constraint { manifoldController.switchoverCount > 0 implies secondaryBank.isActive == true }
        }
    }
}
