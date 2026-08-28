package OpenHAN_System {
    public import ScalarValues::*;

    // ─── Value Types with Units ───
    attribute def Power_kW :> Real { unit 'kW'; }
    attribute def Energy_kWh :> Real { unit 'kWh'; }
    attribute def Temperature_C :> Real { unit 'degC'; }
    attribute def Price_USDperkWh :> Real { unit 'USD/kWh'; }
    attribute def Duration_h :> Real { unit 'h'; }
    attribute def Percentage :> Real { unit '%'; }

    // ─── Enumerations ───
    enum def DemandResponseLevel {
        normal;
        moderate;
        critical;
    }

    enum def PricingPeriod {
        peak;
        midPeak;
        offPeak;
    }

    enum def ApplianceState {
        idle;
        running;
        paused;
        scheduled;
        delayed;
        heating;
        cooling;
    }

    enum def CommandType {
        start;
        stop;
        pause;
        resume;
        schedule;
        delay;
        adjustTemp;
        complete;
    }

    // ─── Item Definitions ───
    item def PriceSchedule {
        attribute currentRate : Price_USDperkWh;
        attribute currentPeriod : PricingPeriod;
        attribute peakRate : Price_USDperkWh = 0.25;
        attribute midPeakRate : Price_USDperkWh = 0.15;
        attribute offPeakRate : Price_USDperkWh = 0.08;
        attribute nextPeriodChange : Duration_h;
    }

    item def DemandResponseSignal {
        attribute level : DemandResponseLevel;
        attribute duration : Duration_h;
        attribute requestedReduction : Power_kW;
        attribute eventId : String;
    }

    item def PowerMeasurement {
        attribute instantaneousPower : Power_kW;
        attribute cumulativeEnergy : Energy_kWh;
        attribute timestamp : String;
    }

    item def ApplianceCommand {
        attribute commandType : CommandType;
        attribute parameter : Real;
        attribute priority : Integer = 0;
    }

    item def ApplianceStatus {
        attribute state : ApplianceState;
        attribute currentPower : Power_kW;
        attribute scheduledStartTime : Duration_h;
        attribute deviceId : String;
    }

    item def SecurityCredential {
        attribute encryptionAlgorithm : String = 'AES-256';
        attribute keyId : String;
        attribute certificateValid : Boolean = true;
    }

    // ─── Port Definitions ───
    port def UtilityCommPort {
        out priceSchedule : PriceSchedule;
        out demandResponse : DemandResponseSignal;
        in acknowledgment : String;
        in credential : SecurityCredential;
    }

    port def MeterDataPort {
        out powerMeasurement : PowerMeasurement;
    }

    port def ApplianceControlPort {
        in command : ApplianceCommand;
        out status : ApplianceStatus;
    }

    // ─── Part Definitions ───

    part def UtilityManagementSystem {
        port utilityPort : UtilityCommPort;

        attribute priceSchedule : PriceSchedule;
        attribute drSignal : DemandResponseSignal;
        attribute gridLoad : Power_kW;
        attribute gridCapacity : Power_kW = 10000.0;

        action def broadcastPriceSchedule {
            out schedule : PriceSchedule;
        }

        action def broadcastDemandResponse {
            out signal : DemandResponseSignal;
        }

        action def receiveAcknowledgment {
            in ack : String;
        }

        state def UtilityOperation {
            entry; then normalOperation;

            state normalOperation {
                entry { drSignal.level = DemandResponseLevel::normal; }
                do broadcastPriceSchedule;
            }

            state gridStress {
                entry { drSignal.level = DemandResponseLevel::moderate; }
                do broadcastDemandResponse;
            }

            state emergency {
                entry { drSignal.level = DemandResponseLevel::critical; }
                do broadcastDemandResponse;
            }

            transition normalOperation to gridStress
                when gridLoad > gridCapacity * 0.85;
            transition gridStress to emergency
                when gridLoad > gridCapacity * 0.95;
            transition emergency to normalOperation
                when gridLoad < gridCapacity * 0.75;
            transition gridStress to normalOperation
                when gridLoad < gridCapacity * 0.80;
        }

        perform UtilityOperation;
    }

    part def SmartElectricMeter {
        port meterPort : MeterDataPort;

        attribute totalPower : Power_kW;
        attribute totalEnergy : Energy_kWh;
        attribute measurementInterval : Duration_h = 0.0167;
        attribute voltage : Real = 240.0;
        attribute current : Real;

        action def measurePower {
            in interval : Duration_h;
            out measurement : PowerMeasurement;
        }

        perform measurePower;
    }

    part def SmartThermostat {
        port appliancePort : ApplianceControlPort;
        port hvacPort : ~ApplianceControlPort;

        attribute setpoint : Temperature_C = 22.0;
        attribute currentTemp : Temperature_C;
        attribute currentState : ApplianceState;
        attribute deadband : Temperature_C = 1.0;
        attribute drAdjustment : Temperature_C = 0.0;
        attribute maxDrAdjustment : Temperature_C = 2.0;
        attribute effectiveSetpoint : Temperature_C;

        action def sendHvacCommand {
            in cmd : ApplianceCommand;
        }

        action def reportStatus {
            out status : ApplianceStatus;
        }

        state def ThermostatOperation {
            entry; then idle;

            state idle;
            state heating {
                entry { effectiveSetpoint = setpoint + drAdjustment; }
                do sendHvacCommand;
            }
            state cooling {
                entry { effectiveSetpoint = setpoint - drAdjustment; }
                do sendHvacCommand;
            }
            state drAdjusted {
                entry { drAdjustment = appliancePort.command.parameter; }
            }

            transition idle to heating
                when currentTemp < setpoint - deadband;
            transition idle to cooling
                when currentTemp > setpoint + deadband;
            transition heating to idle
                when currentTemp >= setpoint;
            transition cooling to idle
                when currentTemp <= setpoint;
            transition heating to drAdjusted
                when appliancePort.command.commandType == CommandType::adjustTemp;
            transition cooling to drAdjusted
                when appliancePort.command.commandType == CommandType::adjustTemp;
            transition drAdjusted to idle
                when appliancePort.command.commandType == CommandType::resume;
            transition drAdjusted to heating
                when currentTemp < effectiveSetpoint - deadband;
            transition drAdjusted to cooling
                when currentTemp > effectiveSetpoint + deadband;
        }

        perform ThermostatOperation;
    }

    part def SmartWaterHeater {
        port appliancePort : ApplianceControlPort;

        attribute tankTemp : Temperature_C;
        attribute currentState : ApplianceState;
        attribute heatingPower : Power_kW = 4.5;
        attribute lowerThreshold : Temperature_C = 50.0;
        attribute upperThreshold : Temperature_C = 60.0;
        attribute scheduledStartTime : Duration_h;
        attribute tankCapacity : Real = 200.0;

        action def reportStatus {
            out status : ApplianceStatus;
        }

        state def WaterHeaterOperation {
            entry; then idle;

            state idle;
            state heating;
            state scheduled;
            state paused;

            transition idle to heating
                when tankTemp < lowerThreshold;
            transition heating to idle
                when tankTemp >= upperThreshold;
            transition idle to scheduled
                when appliancePort.command.commandType == CommandType::schedule;
            transition scheduled to heating
                when appliancePort.command.commandType == CommandType::start;
            transition heating to paused
                when appliancePort.command.commandType == CommandType::pause;
            transition paused to heating
                when appliancePort.command.commandType == CommandType::resume;
            transition paused to idle
                when appliancePort.command.commandType == CommandType::stop;
        }

        perform WaterHeaterOperation;
    }

    part def SmartDryer {
        port appliancePort : ApplianceControlPort;

        attribute currentState : ApplianceState;
        attribute cyclePower : Power_kW = 5.0;
        attribute scheduledDelay : Duration_h;
        attribute cycleDuration : Duration_h = 1.0;
        attribute remainingTime : Duration_h;

        action def reportStatus {
            out status : ApplianceStatus;
        }

        state def DryerOperation {
            entry; then idle;

            state idle;
            state running;
            state delayed;

            transition idle to running
                when appliancePort.command.commandType == CommandType::start;
            transition idle to delayed
                when appliancePort.command.commandType == CommandType::delay;
            transition delayed to running
                when appliancePort.command.commandType == CommandType::start;
            transition running to idle
                when appliancePort.command.commandType == CommandType::complete;
            transition delayed to idle
                when appliancePort.command.commandType == CommandType::stop;
        }

        perform DryerOperation;
    }

    part def HVACSystem {
        port controlPort : ApplianceControlPort;

        attribute heatingPower : Power_kW = 3.5;
        attribute coolingPower : Power_kW = 3.5;
        attribute currentState : ApplianceState;
        attribute airflowRate : Real = 1200.0;

        action def operateHeating {
            in cmd : ApplianceCommand;
        }

        action def operateCooling {
            in cmd : ApplianceCommand;
        }

        state def HVACOperation {
            entry; then standby;

            state standby;
            state heating;
            state cooling;

            transition standby to heating
                when controlPort.command.commandType == CommandType::start;
            transition standby to cooling
                when controlPort.command.commandType == CommandType::start;
            transition heating to standby
                when controlPort.command.commandType == CommandType::stop;
            transition cooling to standby
                when controlPort.command.commandType == CommandType::stop;
        }

        perform HVACOperation;
    }

    part def HomeAreaNetworkGateway {
        port utilityPort : ~UtilityCommPort;
        port meterPort : ~MeterDataPort;
        port thermostatPort : ~ApplianceControlPort;
        port waterHeaterPort : ~ApplianceControlPort;
        port dryerPort : ~ApplianceControlPort;

        attribute priceSchedule : PriceSchedule;
        attribute drSignal : DemandResponseSignal;
        attribute currentPowerDraw : Power_kW;
        attribute baselineSetpoint : Temperature_C = 22.0;
        attribute maxTempAdjustment : Temperature_C = 2.0;
        attribute supportedDevices : Integer = 50;
        attribute uptimePercent : Percentage = 99.5;
        attribute securityCredential : SecurityCredential;
        attribute totalEnergyToday : Energy_kWh = 0.0;
        attribute dailyCost : Real = 0.0;

        action def optimizeForPrice {
            in schedule : PriceSchedule;
            in power : Power_kW;
            out waterHeaterCmd : ApplianceCommand;
            out dryerCmd : ApplianceCommand;
        }

        action def respondToDemandResponse {
            in signal : DemandResponseSignal;
            in power : Power_kW;
            out thermostatCmd : ApplianceCommand;
            out waterHeaterCmd : ApplianceCommand;
            out dryerCmd : ApplianceCommand;
        }

        action def collectMeterData {
            in measurement : PowerMeasurement;
            out power : Power_kW;
        }

        action def calculateCost {
            in energy : Energy_kWh;
            in rate : Price_USDperkWh;
            out cost : Real;
        }

        state def GatewayOperation {
            entry; then monitoring;

            state monitoring {
                entry { currentPowerDraw = meterPort.powerMeasurement.instantaneousPower; }
                do collectMeterData;
            }

            state priceOptimization {
                entry {
                    waterHeaterPort.command.commandType = CommandType::schedule;
                    waterHeaterPort.command.parameter = 0.0;
                    dryerPort.command.commandType = CommandType::delay;
                    dryerPort.command.parameter = 0.0;
                }
                do optimizeForPrice;
            }

            state demandResponse {
                entry {
                    thermostatPort.command.commandType = CommandType::adjustTemp;
                    thermostatPort.command.parameter = 1.0;
                    waterHeaterPort.command.commandType = CommandType::pause;
                    waterHeaterPort.command.parameter = 0.0;
                }
                do respondToDemandResponse;
            }

            state criticalResponse {
                entry {
                    thermostatPort.command.commandType = CommandType::adjustTemp;
                    thermostatPort.command.parameter = 2.0;
                    waterHeaterPort.command.commandType = CommandType::pause;
                    waterHeaterPort.command.parameter = 0.0;
                    dryerPort.command.commandType = CommandType::delay;
                    dryerPort.command.parameter = 0.0;
                }
                do respondToDemandResponse;
            }

            transition monitoring to priceOptimization
                when priceSchedule.currentPeriod == PricingPeriod::peak;
            transition priceOptimization to monitoring
                when priceSchedule.currentPeriod == PricingPeriod::offPeak;
            transition monitoring to demandResponse
                when drSignal.level == DemandResponseLevel::moderate;
            transition demandResponse to criticalResponse
                when drSignal.level == DemandResponseLevel::critical;
            transition criticalResponse to monitoring
                when drSignal.level == DemandResponseLevel::normal;
            transition demandResponse to monitoring
                when drSignal.level == DemandResponseLevel::normal;
            transition priceOptimization to demandResponse
                when drSignal.level == DemandResponseLevel::moderate;
            transition priceOptimization to criticalResponse
                when drSignal.level == DemandResponseLevel::critical;
            transition demandResponse to priceOptimization
                when priceSchedule.currentPeriod == PricingPeriod::peak
                    and drSignal.level == DemandResponseLevel::normal;
        }

        perform GatewayOperation;
    }

    // ─── Top-Level System Assembly ───
    part def OpenHANSystem {
        part utility : UtilityManagementSystem;
        part gateway : HomeAreaNetworkGateway;
        part meter : SmartElectricMeter;
        part thermostat : SmartThermostat;
        part waterHeater : SmartWaterHeater;
        part dryer : SmartDryer;
        part hvac : HVACSystem;

        connection utilityToGateway connect utility.utilityPort to gateway.utilityPort;
        connection meterToGateway connect meter.meterPort to gateway.meterPort;
        connection gatewayToThermostat connect gateway.thermostatPort to thermostat.appliancePort;
        connection gatewayToWaterHeater connect gateway.waterHeaterPort to waterHeater.appliancePort;
        connection gatewayToDryer connect gateway.dryerPort to dryer.appliancePort;
        connection thermostatToHVAC connect thermostat.hvacPort to hvac.controlPort;
    }

    // ─── Requirements ───
    requirement def CostReductionRequirement {
        doc "The system shall reduce homeowner energy costs by optimizing appliance scheduling based on real-time pricing.";
        attribute targetSavingsPercent : Real = 15.0;
        subject system : OpenHANSystem;
        objective {
            system.gateway.priceSchedule.currentPeriod == PricingPeriod::offPeak
            implies system.waterHeater.currentState == ApplianceState::scheduled
                or system.waterHeater.currentState == ApplianceState::heating;
        }
    }

    requirement def GridSupportRequirement {
        doc "The system shall respond to demand response signals by reducing consumption during grid stress events.";
        subject system : OpenHANSystem;
        objective {
            system.gateway.drSignal.level == DemandResponseLevel::critical
            implies system.waterHeater.currentState == ApplianceState::paused;
        }
    }

    requirement def ComfortRequirement {
        doc "The system shall maintain occupant comfort by limiting thermostat adjustments to 2 degrees during demand response events.";
        subject system : OpenHANSystem;
        attribute maxAdjustment : Temperature_C = 2.0;
        objective {
            system.gateway.drSignal.level != DemandResponseLevel::normal
            implies system.thermostat.drAdjustment <= maxAdjustment;
        }
    }

    requirement def SecurityRequirement {
        doc "The system shall use secure encrypted communication channels between the utility and all home devices.";
        subject system : OpenHANSystem;
        attribute encryptionRequired : Boolean = true;
        attribute minKeyLength : Integer = 256;
        objective {
            system.gateway.securityCredential.encryptionAlgorithm == 'AES-256'
            implies system.gateway.securityCredential.certificateValid == true;
        }
    }

    requirement def ReliabilityRequirement {
        doc "The system shall maintain 99.5% uptime for the home area network gateway.";
        subject system : OpenHANSystem;
        attribute minUptimePercent : Real = 99.5;
        objective {
            system.gateway.uptimePercent >= minUptimePercent;
        }
    }

    requirement def ScalabilityRequirement {
        doc "The system shall support at least 50 smart devices within the home area network.";
        subject system : OpenHANSystem;
        attribute minSupportedDevices : Integer = 50;
        objective {
            system.gateway.supportedDevices >= minSupportedDevices;
        }
    }

    requirement def DryerDelayRequirement {
        doc "The system shall delay dryer cycle start during peak pricing periods.";
        subject system : OpenHANSystem;
        objective {
            system.gateway.priceSchedule.currentPeriod == PricingPeriod::peak
            implies system.dryer.currentState == ApplianceState::delayed;
        }
    }

    requirement def WaterHeaterSchedulingRequirement {
        doc "The system shall schedule water heater heating cycles during off-peak periods to minimize energy cost.";
        subject system : OpenHANSystem;
        objective {
            system.gateway.priceSchedule.currentPeriod == PricingPeriod::offPeak
            implies system.waterHeater.currentState == ApplianceState::heating
                or system.waterHeater.currentState == ApplianceState::scheduled;
        }
    }

    requirement def CriticalDRThermostatRequirement {
        doc "During critical demand response events, the system shall adjust the thermostat setpoint by up to 2 degrees.";
        subject system : OpenHANSystem;
        attribute maxAdjustment : Temperature_C = 2.0;
        objective {
            system.gateway.drSignal.level == DemandResponseLevel::critical
            implies system.thermostat.drAdjustment > 0.0
                and system.thermostat.drAdjustment <= maxAdjustment;
        }
    }

    requirement def MeteringAccuracyRequirement {
        doc "The smart electric meter shall measure total household power consumption with accuracy within plus or minus 0.5 percent.";
        subject system : OpenHANSystem;
        attribute maxErrorPercent : Real = 0.5;
        objective {
            system.meter.measurementInterval <= 0.0167;
        }
    }

    // ─── Requirement Group ───
    part def OpenHANRequirements {
        requirement costReduction : CostReductionRequirement;
        requirement gridSupport : GridSupportRequirement;
        requirement comfort : ComfortRequirement;
        requirement security : SecurityRequirement;
        requirement reliability : ReliabilityRequirement;
        requirement scalability : ScalabilityRequirement;
        requirement dryerDelay : DryerDelayRequirement;
        requirement waterHeaterScheduling : WaterHeaterSchedulingRequirement;
        requirement criticalDRThermostat : CriticalDRThermostatRequirement;
        requirement meteringAccuracy : MeteringAccuracyRequirement;
    }
}
