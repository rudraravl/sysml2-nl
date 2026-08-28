package ArcticSunTemperatureManagementSystem {

    package Units {
        item def TemperatureUnit;
        item degC :> TemperatureUnit;
        item def VolumeUnit;
        item liter :> VolumeUnit;
        item def FlowRateUnit;
        item literPerMin :> FlowRateUnit;
        item def PowerUnit;
        item watt :> PowerUnit;
        item def TimeUnit;
        item minute :> TimeUnit;
        item def DimensionlessUnit;
        item percent :> DimensionlessUnit;
        item def RotationalSpeedUnit;
        item rpm :> RotationalSpeedUnit;
    }

    value def Temperature :> Real { unit :> Units::degC; }
    value def Volume :> Real { unit :> Units::liter; }
    value def FlowRate :> Real { unit :> Units::literPerMin; }
    value def Power :> Real { unit :> Units::watt; }
    value def Duration :> Real { unit :> Units::minute; }
    value def Percent :> Real { unit :> Units::percent; }
    value def PumpSpeed :> Real { unit :> Units::rpm; }

    item def CoolingFluid;
    item def ThermalEnergy;

    port def FluidPort { out item fluid : CoolingFluid; }
    port def TempSensorPort { out attribute tempValue : Temperature; }
    port def LevelSensorPort { out attribute levelValue : Percent; out attribute lowAlarm : Boolean; }
    port def PumpControlPort {
        out attribute speed : PumpSpeed;
        out attribute enable : Boolean;
        in attribute actualSpeed : PumpSpeed;
        in attribute fault : Boolean;
    }
    port def HeaterControlPort {
        out attribute setpoint : Temperature;
        out attribute enable : Boolean;
        in attribute actualTemp : Temperature;
        in attribute fault : Boolean;
    }
    port def AlarmPort { out attribute code : String; out attribute severity : String; }
    port def UIPort {
        out attribute targetTemp : Temperature;
        out attribute startCmd : Boolean;
        out attribute stopCmd : Boolean;
        out attribute primeCmd : Boolean;
        in attribute patientTemp : Temperature;
        in attribute fluidTemp : Temperature;
        in attribute phase : String;
        in attribute alarmMsg : String;
    }
    port def PowerPort {
        out attribute available : Boolean;
        out attribute batteryActive : Boolean;
        out attribute batteryRemaining : Duration;
    }

    requirement def TemperatureControlRequirement {
        doc "The system shall maintain patient core temperature within plus or minus 0.2 degrees C of the target set by the clinician.";
        attribute targetTemperature : Temperature;
        attribute tolerance : Temperature = 0.2;
        subject patientTemp : Temperature;
        require { patientTemp >= targetTemperature - tolerance and patientTemp <= targetTemperature + tolerance }
    }

    requirement def BatteryBackupRequirement {
        doc "The system shall sustain operation for at least 30 minutes on battery backup in case of power failure.";
        attribute minBackupDuration : Duration = 30;
        attribute batteryBackupDuration : Duration;
        require { batteryBackupDuration >= minBackupDuration }
    }

    requirement def AlarmRequirement {
        doc "The system shall raise an alarm for temperature deviations exceeding 0.5 degrees C, low fluid level, or pump failure.";
        attribute tempDeviation : Boolean;
        attribute lowFluidLevel : Boolean;
        attribute pumpFailure : Boolean;
        attribute alarmRaised : Boolean;
        require { alarmRaised == (tempDeviation or lowFluidLevel or pumpFailure) }
    }

    requirement def TherapyProtocolRequirement {
        doc "The system shall execute induction, maintenance, and rewarming phases in sequence during active therapy.";
        attribute phaseInduction : String = "induction";
        attribute phaseMaintenance : String = "maintenance";
        attribute phaseRewarming : String = "rewarming";
        require { phaseInduction == "induction" and phaseMaintenance == "maintenance" and phaseRewarming == "rewarming" }
    }

    requirement def PrimingRequirement {
        doc "The system shall prime the fluid circuit before starting active therapy to remove air from the loop.";
        attribute primingComplete : Boolean;
        require { primingComplete == true }
    }

    requirement def NonInvasiveRequirement {
        doc "The system shall manage patient temperature non-invasively using gel pads applied to the skin with circulating temperature-controlled fluid.";
        attribute method : String = "non-invasive";
        require { method == "non-invasive" }
    }

    part def Patient {
        port coreTempOut : TempSensorPort;
        attribute coreTemp : Temperature = 37.0;
        attribute targetTemp : Temperature = 37.0;
        attribute weight : Real = 70.0;

        exhibit {
            do { coreTempOut.tempValue := coreTemp; }
        }
    }

    part def FluidReservoir {
        port fluidOut : FluidPort;
        port fluidIn : FluidPort;
        port levelOut : LevelSensorPort;
        attribute capacity : Volume = 10.0;
        attribute currentLevel : Percent = 100.0;
        attribute lowLevelThreshold : Percent = 20.0;
        attribute currentVolume : Volume = 10.0;

        exhibit {
            entry; then NormalLevel;

            state NormalLevel {
                entry {
                    levelOut.lowAlarm := false;
                    levelOut.levelValue := currentLevel;
                }
                do { levelOut.levelValue := currentLevel; }
                transition NormalLevel to LowLevel when currentLevel < lowLevelThreshold;
            }

            state LowLevel {
                entry {
                    levelOut.lowAlarm := true;
                    levelOut.levelValue := currentLevel;
                }
                do { levelOut.levelValue := currentLevel; }
                transition LowLevel to NormalLevel when currentLevel >= lowLevelThreshold;
            }
        }
    }

    part def CirculationPump {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port control : PumpControlPort;
        port powerIn : PowerPort;
        attribute maxSpeed : PumpSpeed = 3000.0;
        attribute currentSpeed : PumpSpeed = 0.0;
        attribute nominalFlowRate : FlowRate = 4.0;
        attribute failed : Boolean = false;
        attribute powerOn : Boolean = true;

        exhibit {
            entry; then Idle;

            state Idle {
                entry {
                    currentSpeed := 0.0;
                    control.actualSpeed := 0.0;
                    control.fault := false;
                }
                do { control.actualSpeed := currentSpeed; }
                transition Idle to Running when control.enable == true and powerOn == true;
                transition Idle to Failed when powerOn == false;
            }

            state Running {
                entry {
                    currentSpeed := control.speed;
                    control.actualSpeed := currentSpeed;
                }
                do {
                    fluidOut.fluid := fluidIn.fluid;
                    control.actualSpeed := currentSpeed;
                }
                transition Running to Idle when control.enable == false;
                transition Running to Failed when failed == true or powerOn == false;
            }

            state Failed {
                entry {
                    currentSpeed := 0.0;
                    control.actualSpeed := 0.0;
                    control.fault := true;
                }
            }
        }
    }

    part def HeatExchanger {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port control : HeaterControlPort;
        port powerIn : PowerPort;
        port fluidTempOut : TempSensorPort;
        attribute maxHeatingPower : Power = 500.0;
        attribute maxCoolingPower : Power = 500.0;
        attribute currentPower : Power = 0.0;
        attribute fluidTempSetpoint : Temperature = 37.0;
        attribute currentFluidTemp : Temperature = 37.0;
        attribute powerOn : Boolean = true;

        exhibit {
            entry; then Idle;

            state Idle {
                entry {
                    currentPower := 0.0;
                    control.actualTemp := currentFluidTemp;
                    fluidTempOut.tempValue := currentFluidTemp;
                }
                do {
                    fluidOut.fluid := fluidIn.fluid;
                    fluidTempOut.tempValue := currentFluidTemp;
                    control.actualTemp := currentFluidTemp;
                }
                transition Idle to Active when control.enable == true and powerOn == true;
            }

            state Active {
                entry {
                    fluidTempSetpoint := control.setpoint;
                    control.actualTemp := currentFluidTemp;
                }
                do {
                    if currentFluidTemp > fluidTempSetpoint then {
                        currentPower := -maxCoolingPower;
                    } else {
                        currentPower := maxHeatingPower;
                    }
                    fluidOut.fluid := fluidIn.fluid;
                    fluidTempOut.tempValue := currentFluidTemp;
                    control.actualTemp := currentFluidTemp;
                }
                transition Active to Idle when control.enable == false;
                transition Active to Idle when powerOn == false;
            }
        }
    }

    part def CoolingPad {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        attribute padId : String;
        attribute padArea : Real = 0.05;
        attribute padTemp : Temperature = 37.0;
        attribute heatTransferRate : Power = 0.0;
        attribute patientContact : Boolean = true;

        exhibit action HeatExchange {
            in patientTemp : Temperature;
            in fluidTemp : Temperature;
            out transferredHeat : ThermalEnergy;
            do { fluidOut.fluid := fluidIn.fluid; }
        }
    }

    part def TemperatureSensor {
        port tempIn : TempSensorPort;
        port tempOut : TempSensorPort;
        attribute sensorType : String;
        attribute measuredTemp : Temperature = 37.0;
        attribute accuracy : Temperature = 0.1;
        attribute samplingRate : Real = 1.0;

        exhibit {
            do {
                measuredTemp := tempIn.tempValue;
                tempOut.tempValue := measuredTemp;
            }
        }
    }

    part def ControlModule {
        port patientTempIn : TempSensorPort;
        port fluidTempIn : TempSensorPort;
        port levelIn : LevelSensorPort;
        port pumpCmd : PumpControlPort;
        port heaterCmd : HeaterControlPort;
        port ui : UIPort;
        port alarmOut : AlarmPort;
        port powerIn : PowerPort;

        attribute targetTemperature : Temperature = 37.0;
        attribute currentPatientTemp : Temperature = 37.0;
        attribute currentFluidTemp : Temperature = 37.0;
        attribute currentPhase : String = "standby";
        attribute inductionRate : Temperature = 1.5;
        attribute maintenanceDuration : Duration = 1440.0;
        attribute rewarmingRate : Temperature = 0.25;
        attribute tempDeviationThreshold : Temperature = 0.5;
        attribute lowFluidAlarm : Boolean = false;
        attribute pumpFault : Boolean = false;
        attribute powerAvailable : Boolean = true;
        attribute batteryActive : Boolean = false;
        attribute alarmCode : String = "";
        attribute alarmSeverity : String = "";

        exhibit {
            entry; then Standby;

            state Standby {
                entry {
                    currentPhase := "standby";
                    pumpCmd.enable := false;
                    pumpCmd.speed := 0.0;
                    heaterCmd.enable := false;
                }
                do {
                    if ui.targetTemp != targetTemperature then { targetTemperature := ui.targetTemp; }
                    currentPatientTemp := patientTempIn.tempValue;
                    currentFluidTemp := fluidTempIn.tempValue;
                    ui.patientTemp := currentPatientTemp;
                    ui.fluidTemp := currentFluidTemp;
                    ui.phase := currentPhase;
                    ui.alarmMsg := "";
                    powerAvailable := powerIn.available;
                    batteryActive := powerIn.batteryActive;
                }
                transition Standby to Priming when ui.primeCmd == true;
            }

            state Priming {
                entry {
                    currentPhase := "priming";
                    pumpCmd.enable := true;
                    pumpCmd.speed := 1500.0;
                    heaterCmd.enable := false;
                }
                do {
                    currentPatientTemp := patientTempIn.tempValue;
                    currentFluidTemp := fluidTempIn.tempValue;
                    ui.patientTemp := currentPatientTemp;
                    ui.fluidTemp := currentFluidTemp;
                    ui.phase := currentPhase;
                    if levelIn.lowAlarm == true then {
                        alarmOut.code := "LOW_FLUID";
                        alarmOut.severity := "HIGH";
                        ui.alarmMsg := "LOW_FLUID";
                    }
                    if pumpCmd.fault == true then {
                        alarmOut.code := "PUMP_FAILURE";
                        alarmOut.severity := "CRITICAL";
                        ui.alarmMsg := "PUMP_FAILURE";
                    }
                }
                transition Priming to Active when ui.startCmd == true and levelIn.lowAlarm == false;
                transition Priming to Standby when ui.stopCmd == true;
            }

            state Active {
                entry { currentPhase := "active"; }
                then Induction;

                state Induction {
                    entry {
                        currentPhase := "induction";
                        pumpCmd.enable := true;
                        pumpCmd.speed := 2500.0;
                        heaterCmd.enable := true;
                        heaterCmd.setpoint := targetTemperature;
                    }
                    do {
                        currentPatientTemp := patientTempIn.tempValue;
                        currentFluidTemp := fluidTempIn.tempValue;
                        ui.patientTemp := currentPatientTemp;
                        ui.fluidTemp := currentFluidTemp;
                        ui.phase := currentPhase;
                        if levelIn.lowAlarm == true then {
                            alarmOut.code := "LOW_FLUID";
                            alarmOut.severity := "HIGH";
                            ui.alarmMsg := "LOW_FLUID";
                        }
                        if pumpCmd.fault == true then {
                            alarmOut.code := "PUMP_FAILURE";
                            alarmOut.severity := "CRITICAL";
                            ui.alarmMsg := "PUMP_FAILURE";
                        }
                        if currentPatientTemp - targetTemperature > tempDeviationThreshold or targetTemperature - currentPatientTemp > tempDeviationThreshold then {
                            alarmOut.code := "TEMP_DEVIATION";
                            alarmOut.severity := "MEDIUM";
                            ui.alarmMsg := "TEMP_DEVIATION";
                        }
                    }
                    transition Induction to Maintenance when currentPatientTemp - targetTemperature <= 0.2 and targetTemperature - currentPatientTemp <= 0.2;
                }

                state Maintenance {
                    entry {
                        currentPhase := "maintenance";
                        pumpCmd.enable := true;
                        pumpCmd.speed := 1000.0;
                        heaterCmd.enable := true;
                        heaterCmd.setpoint := targetTemperature;
                    }
                    do {
                        currentPatientTemp := patientTempIn.tempValue;
                        currentFluidTemp := fluidTempIn.tempValue;
                        ui.patientTemp := currentPatientTemp;
                        ui.fluidTemp := currentFluidTemp;
                        ui.phase := currentPhase;
                        if levelIn.lowAlarm == true then {
                            alarmOut.code := "LOW_FLUID";
                            alarmOut.severity := "HIGH";
                            ui.alarmMsg := "LOW_FLUID";
                        }
                        if pumpCmd.fault == true then {
                            alarmOut.code := "PUMP_FAILURE";
                            alarmOut.severity := "CRITICAL";
                            ui.alarmMsg := "PUMP_FAILURE";
                        }
                        if currentPatientTemp - targetTemperature > tempDeviationThreshold or targetTemperature - currentPatientTemp > tempDeviationThreshold then {
                            alarmOut.code := "TEMP_DEVIATION";
                            alarmOut.severity := "MEDIUM";
                            ui.alarmMsg := "TEMP_DEVIATION";
                        }
                    }
                    transition Maintenance to Rewarming when ui.startCmd == true;
                }

                state Rewarming {
                    entry {
                        currentPhase := "rewarming";
                        pumpCmd.enable := true;
                        pumpCmd.speed := 800.0;
                        heaterCmd.enable := true;
                        heaterCmd.setpoint := 37.0;
                    }
                    do {
                        currentPatientTemp := patientTempIn.tempValue;
                        currentFluidTemp := fluidTempIn.tempValue;
                        ui.patientTemp := currentPatientTemp;
                        ui.fluidTemp := currentFluidTemp;
                        ui.phase := currentPhase;
                        if levelIn.lowAlarm == true then {
                            alarmOut.code := "LOW_FLUID";
                            alarmOut.severity := "HIGH";
                            ui.alarmMsg := "LOW_FLUID";
                        }
                        if pumpCmd.fault == true then {
                            alarmOut.code := "PUMP_FAILURE";
                            alarmOut.severity := "CRITICAL";
                            ui.alarmMsg := "PUMP_FAILURE";
                        }
                    }
                    transition Rewarming to Standby when currentPatientTemp - 37.0 <= 0.2 and 37.0 - currentPatientTemp <= 0.2;
                }

                transition Active to Standby when ui.stopCmd == true;
            }
        }
    }

    part def UserInterface {
        port ui : UIPort;
        port powerIn : PowerPort;
        attribute displayTargetTemp : Temperature = 37.0;
        attribute displayPatientTemp : Temperature = 37.0;
        attribute displayFluidTemp : Temperature = 37.0;
        attribute displayPhase : String = "standby";
        attribute displayAlarmMsg : String = "";
        attribute clinicianStartCmd : Boolean = false;
        attribute clinicianStopCmd : Boolean = false;
        attribute clinicianPrimeCmd : Boolean = false;
        attribute powerOn : Boolean = true;

        exhibit {
            entry; then Monitoring;

            state Monitoring {
                do {
                    ui.targetTemp := displayTargetTemp;
                    ui.startCmd := clinicianStartCmd;
                    ui.stopCmd := clinicianStopCmd;
                    ui.primeCmd := clinicianPrimeCmd;
                    displayPatientTemp := ui.patientTemp;
                    displayFluidTemp := ui.fluidTemp;
                    displayPhase := ui.phase;
                    displayAlarmMsg := ui.alarmMsg;
                    powerOn := powerIn.available;
                }
            }
        }
    }

    part def AlarmSystem {
        port alarmIn : AlarmPort;
        attribute activeAlarms : String[*];
        attribute alarmActive : Boolean = false;
        attribute lastAlarmCode : String = "";
        attribute lastAlarmSeverity : String = "";

        exhibit {
            entry; then Clear;

            state Clear {
                entry { alarmActive := false; }
                do {
                    if alarmIn.code != "" and alarmIn.code != "CLEAR" then {
                        lastAlarmCode := alarmIn.code;
                        lastAlarmSeverity := alarmIn.severity;
                    }
                }
                transition Clear to Active when alarmIn.code != "" and alarmIn.code != "CLEAR";
            }

            state Active {
                entry {
                    alarmActive := true;
                    lastAlarmCode := alarmIn.code;
                    lastAlarmSeverity := alarmIn.severity;
                    activeAlarms := activeAlarms + alarmIn.code;
                }
                transition Active to Clear when alarmIn.code == "CLEAR";
            }
        }
    }

    part def PowerSupply {
        port powerOut : PowerPort;
        attribute mainPowerActive : Boolean = true;
        attribute batteryCapacity : Duration = 30.0;
        attribute batteryRemaining : Duration = 30.0;
        attribute batteryActive : Boolean = false;
        attribute chargingRate : Real = 1.0;

        exhibit {
            entry; then MainPower;

            state MainPower {
                entry {
                    batteryActive := false;
                    powerOut.available := true;
                    powerOut.batteryActive := false;
                    powerOut.batteryRemaining := batteryCapacity;
                }
                do {
                    powerOut.available := true;
                    powerOut.batteryActive := false;
                    powerOut.batteryRemaining := batteryCapacity;
                    if batteryRemaining < batteryCapacity then {
                        batteryRemaining := batteryRemaining + chargingRate * 0.1;
                    }
                }
                transition MainPower to BatteryBackup when mainPowerActive == false;
            }

            state BatteryBackup {
                entry {
                    batteryActive := true;
                    powerOut.batteryActive := true;
                    powerOut.available := true;
                }
                do {
                    batteryRemaining := batteryRemaining - 0.1;
                    powerOut.batteryRemaining := batteryRemaining;
                    powerOut.available := true;
                    powerOut.batteryActive := true;
                }
                transition BatteryBackup to PowerLost when batteryRemaining <= 0.0;
                transition BatteryBackup to MainPower when mainPowerActive == true;
            }

            state PowerLost {
                entry {
                    powerOut.available := false;
                    powerOut.batteryActive := false;
                    powerOut.batteryRemaining := 0.0;
                }
                transition PowerLost to MainPower when mainPowerActive == true;
            }
        }
    }

    part def ArcticSunSystem {
        attribute systemName : String = "Arctic Sun Temperature Management System";
        attribute manufacturer : String = "BD";
        attribute model : String = "Arctic Sun 5000";
        attribute systemSerial : String = "AS5000-001";

        part reservoir : FluidReservoir {
            attribute capacity : Volume = 10.0;
        }
        part pump : CirculationPump;
        part heatExchanger : HeatExchanger;
        part pads : CoolingPad[4] {
            attribute padId := {"pad1", "pad2", "pad3", "pad4"};
        }
        part patientTempSensor : TemperatureSensor { attribute sensorType := "core"; }
        part fluidTempSensor : TemperatureSensor { attribute sensorType := "fluid"; }
        part controller : ControlModule;
        part ui : UserInterface;
        part alarmSystem : AlarmSystem;
        part powerSupply : PowerSupply;
        part patient : Patient;

        connect reservoir.fluidOut to pump.fluidIn;
        connect pump.fluidOut to heatExchanger.fluidIn;
        connect heatExchanger.fluidOut to pads[1].fluidIn;
        connect pads[1].fluidOut to pads[2].fluidIn;
        connect pads[2].fluidOut to pads[3].fluidIn;
        connect pads[3].fluidOut to pads[4].fluidIn;
        connect pads[4].fluidOut to reservoir.fluidIn;

        connect patient.coreTempOut to patientTempSensor.tempIn;
        connect patientTempSensor.tempOut to controller.patientTempIn;
        connect heatExchanger.fluidTempOut to fluidTempSensor.tempIn;
        connect fluidTempSensor.tempOut to controller.fluidTempIn;
        connect reservoir.levelOut to controller.levelIn;

        connect controller.pumpCmd to pump.control;
        connect controller.heaterCmd to heatExchanger.control;

        connect ui.ui to controller.ui;
        connect controller.alarmOut to alarmSystem.alarmIn;

        connect powerSupply.powerOut to controller.powerIn;
        connect powerSupply.powerOut to pump.powerIn;
        connect powerSupply.powerOut to heatExchanger.powerIn;
        connect powerSupply.powerOut to ui.powerIn;

        satisfy TemperatureControlRequirement by controller;
        satisfy BatteryBackupRequirement by powerSupply;
        satisfy AlarmRequirement by alarmSystem;
        satisfy TherapyProtocolRequirement by controller;
        satisfy PrimingRequirement by controller;
        satisfy NonInvasiveRequirement by pads;
    }
}
