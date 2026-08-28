package OpenHAN {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    private import Time::*;

    item def PriceSignal {
        attribute rate : Real;
        attribute currency : String;
        attribute tier : String;
    }

    item def DemandResponseSignal {
        attribute urgency : String;
        attribute requestedReduction : PowerValue;
    }

    item def PowerMeasurement {
        attribute totalPower : PowerValue;
        attribute timestamp : TimeInstantValue;
    }

    item def ConsumptionReport {
        attribute averagePower : PowerValue;
        attribute reportingPeriod : DurationValue;
    }

    item def ThermostatCommand {
        attribute targetTemperature : TemperatureValue;
        attribute mode : String;
    }

    item def ThermostatStatus {
        attribute currentTemperature : TemperatureValue;
        attribute setpoint : TemperatureValue;
        attribute hvacActive : Boolean;
    }

    item def WaterHeaterCommand {
        attribute enableHeating : Boolean;
        attribute targetTemperature : TemperatureValue;
    }

    item def WaterHeaterStatus {
        attribute currentTemperature : TemperatureValue;
        attribute heatingActive : Boolean;
    }

    item def DryerCommand {
        attribute enabled : Boolean;
        attribute startDelay : DurationValue;
    }

    item def DryerStatus {
        attribute cycleRunning : Boolean;
        attribute remainingTime : DurationValue;
    }

    part def UtilityManagementSystem {
        port utilityPort {
            out priceSignal : PriceSignal;
            out demandResponse : DemandResponseSignal;
            in consumptionReport : ConsumptionReport;
        }

        exhibit state utilityStates {
            entry; then normal;
            state normal;
            accept after 3600[SI::s] then peakPricing;
            state peakPricing {
                entry send new PriceSignal(rate=0.25, currency="USD", tier="peak") to utilityPort.priceSignal;
            }
            accept after 3600[SI::s] then offPeakPricing;
            state offPeakPricing {
                entry send new PriceSignal(rate=0.10, currency="USD", tier="off-peak") to utilityPort.priceSignal;
            }
            accept after 3600[SI::s] then normal;
        }
    }

    part def SmartElectricMeter {
        port meterPort {
            out powerData : PowerMeasurement;
        }
        attribute currentPower : PowerValue;

        action measurePower {
            out power : PowerMeasurement;
            assign power := new PowerMeasurement(totalPower = currentPower);
        }
        flow powerFlow of PowerMeasurement from measurePower.power to meterPort.powerData;
    }

    part def SmartThermostat {
        port appliancePort {
            in command : ThermostatCommand;
            out status : ThermostatStatus;
        }
        attribute currentTemp : TemperatureValue;
        attribute setpoint : TemperatureValue;

        exhibit state thermostatStates {
            entry; then idle;
            state idle;
            accept command : ThermostatCommand via appliancePort.command then adjusting;
            state adjusting {
                entry assign currentTemp := setpoint;
            }
            accept after 300[SI::s] then idle;
        }
    }

    part def SmartWaterHeater {
        port appliancePort {
            in command : WaterHeaterCommand;
            out status : WaterHeaterStatus;
        }
        attribute tankTemp : TemperatureValue;
        attribute isHeating : Boolean;

        exhibit state waterHeaterStates {
            entry; then heating;
            state heating {
                entry assign isHeating := true;
            }
            accept command : WaterHeaterCommand via appliancePort.command then paused;
            state paused {
                entry assign isHeating := false;
            }
            accept command : WaterHeaterCommand via appliancePort.command then heating;
        }
    }

    part def SmartDryer {
        port appliancePort {
            in command : DryerCommand;
            out status : DryerStatus;
        }
        attribute cycleDelayed : Boolean;

        exhibit state dryerStates {
            entry; then ready;
            state ready;
            accept command : DryerCommand via appliancePort.command then delayed;
            state delayed {
                entry assign cycleDelayed := true;
            }
            accept after 3600[SI::s] then running;
            state running;
            accept after 300[SI::s] then ready;
        }
    }

    part def HomeAreaNetworkGateway {
        port utilityPort {
            in priceSignal : PriceSignal;
            in demandResponse : DemandResponseSignal;
            out consumptionReport : ConsumptionReport;
        }
        port meterPort {
            in powerData : PowerMeasurement;
        }
        port thermostatPort {
            out command : ThermostatCommand;
            in status : ThermostatStatus;
        }
        port waterHeaterPort {
            out command : WaterHeaterCommand;
            in status : WaterHeaterStatus;
        }
        port dryerPort {
            out command : DryerCommand;
            in status : DryerStatus;
        }

        ref currentPrice : PriceSignal;
        ref currentDR : DemandResponseSignal;

        exhibit state gatewayStates {
            entry; then monitoring;
            state monitoring;
            accept price : PriceSignal via utilityPort.priceSignal
                do assign currentPrice := price
                then evaluatePricing;
            accept dr : DemandResponseSignal via utilityPort.demandResponse
                do assign currentDR := dr
                then evaluateDR;
            state evaluatePricing;
            accept when currentPrice.tier == "peak"
                then shedLoads;
            accept when currentPrice.tier != "peak"
                then monitoring;
            state shedLoads {
                entry {
                    send new WaterHeaterCommand(enableHeating=false, targetTemperature=323[SI::K]) to waterHeaterPort.command;
                    send new DryerCommand(enabled=false, startDelay=3600[SI::s]) to dryerPort.command;
                }
            }
            accept when true
                then monitoring;
            state evaluateDR;
            accept when currentDR.urgency == "critical"
                then criticalResponse;
            accept when currentDR.urgency == "moderate"
                then moderateResponse;
            accept when currentDR.urgency == "normal"
                then monitoring;
            state criticalResponse {
                entry {
                    send new ThermostatCommand(targetTemperature=295[SI::K], mode="adjust") to thermostatPort.command;
                    send new WaterHeaterCommand(enableHeating=false, targetTemperature=323[SI::K]) to waterHeaterPort.command;
                    send new DryerCommand(enabled=false, startDelay=3600[SI::s]) to dryerPort.command;
                }
            }
            accept when true
                then monitoring;
            state moderateResponse {
                entry send new DryerCommand(enabled=false, startDelay=1800[SI::s]) to dryerPort.command;
            }
            accept when true
                then monitoring;
        }
    }

    part utility : UtilityManagementSystem;
    part meter : SmartElectricMeter;
    part gateway : HomeAreaNetworkGateway;
    part thermostat : SmartThermostat;
    part waterHeater : SmartWaterHeater;
    part dryer : SmartDryer;

    interface utilityToGateway connect utility.utilityPort to gateway.utilityPort {
        flow priceFlow of PriceSignal from utility.utilityPort.priceSignal to gateway.utilityPort.priceSignal;
        flow drFlow of DemandResponseSignal from utility.utilityPort.demandResponse to gateway.utilityPort.demandResponse;
        flow reportFlow of ConsumptionReport from gateway.utilityPort.consumptionReport to utility.utilityPort.consumptionReport;
    }

    interface meterToGateway connect meter.meterPort to gateway.meterPort {
        flow powerFlow of PowerMeasurement from meter.meterPort.powerData to gateway.meterPort.powerData;
    }

    interface gatewayToThermostat connect gateway.thermostatPort to thermostat.appliancePort {
        flow cmdFlow of ThermostatCommand from gateway.thermostatPort.command to thermostat.appliancePort.command;
        flow statusFlow of ThermostatStatus from thermostat.appliancePort.status to gateway.thermostatPort.status;
    }

    interface gatewayToWaterHeater connect gateway.waterHeaterPort to waterHeater.appliancePort {
        flow cmdFlow of WaterHeaterCommand from gateway.waterHeaterPort.command to waterHeater.appliancePort.command;
        flow statusFlow of WaterHeaterStatus from waterHeater.appliancePort.status to gateway.waterHeaterPort.status;
    }

    interface gatewayToDryer connect gateway.dryerPort to dryer.appliancePort {
        flow cmdFlow of DryerCommand from gateway.dryerPort.command to dryer.appliancePort.command;
        flow statusFlow of DryerStatus from dryer.appliancePort.status to gateway.dryerPort.status;
    }

    package Requirements {
        private import ScalarValues::*;
        private import ISQ::*;

        requirement def EnergyCostReductionReq {
            doc /* The system shall reduce homeowner electricity costs by scheduling high-power appliances during off-peak periods. */
            attribute actualCost : Real;
            attribute baselineCost : Real;
            require constraint { actualCost <= baselineCost * 0.85 }
        }

        requirement def GridStabilityReq {
            doc /* The system shall respond to demand response signals and reduce load according to urgency level. */
            attribute responseTime : DurationValue;
            attribute maxResponseTime : DurationValue;
            attribute loadReduction : PowerValue;
            attribute targetReduction : PowerValue;
            require constraint { responseTime <= maxResponseTime }
            require constraint { loadReduction >= targetReduction }
        }

        requirement def ComfortMaintenanceReq {
            doc /* The system shall maintain occupant comfort by limiting temperature adjustments to 2 degrees during demand response events. */
            attribute tempAdjustment : TemperatureValue;
            attribute maxAdjustment : TemperatureValue;
            require constraint { tempAdjustment <= maxAdjustment }
        }

        requirement def SecurityReq {
            doc /* The system shall secure all communications between utility, gateway, and appliances using encryption. */
            attribute encryptionEnabled : Boolean;
            require constraint { encryptionEnabled == true }
        }

        requirement def ReliabilityReq {
            doc /* The system shall operate reliably with 99.9 percent uptime supporting numerous smart devices. */
            attribute uptime : Real;
            attribute minUptime : Real;
            attribute connectedDevices : Integer;
            attribute minDevices : Integer;
            require constraint { uptime >= minUptime }
            require constraint { connectedDevices >= minDevices }
        }
    }
}
