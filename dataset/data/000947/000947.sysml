package 'Szczecin Water Pump System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PumpStartCommand;
    attribute def PumpStopCommand;
    attribute def EmergencyShutdownSignal;
    
    item def Water;
    
    port def WaterInletPort {
        in item water : Water;
        in attribute inletPressure : PressureValue;
        in attribute inletFlowRate : VolumeFlowRateValue;
    }
    
    port def WaterOutletPort {
        out item water : Water;
        out attribute outletPressure : PressureValue;
        out attribute outletFlowRate : VolumeFlowRateValue;
    }
    
    port def PowerSupplyPort {
        in attribute voltage : VoltageValue;
        in attribute current : ElectricCurrentValue;
        in attribute powerConsumption : PowerValue;
    }
    
    port def ControlPort {
        in attribute commandSignal : Real;
        out attribute statusFeedback : Real;
    }
    
    part def IntakeReservoir {
        attribute capacity : VolumeValue;
        attribute currentLevel : LengthValue;
        attribute maxLevel : LengthValue;
        attribute minLevel : LengthValue;
        port outlet : WaterOutletPort;
    }
    
    part def DistributionNetwork {
        attribute requiredPressure : PressureValue;
        attribute demandFlowRate : VolumeFlowRateValue;
        port inlet : WaterInletPort;
    }
    
    part def ElectricMotor {
        attribute ratedPower : PowerValue;
        attribute operatingSpeed : AngularVelocityValue;
        attribute efficiency : Real;
        port powerInput : PowerSupplyPort;
        
        action def DriveShaft {
            in powerLevel : PowerValue;
            out torque : TorqueValue;
            out speed : AngularVelocityValue;
        }
    }
    
    part def CentrifugalPump {
        attribute impellerDiameter : LengthValue;
        attribute ratedFlowRate : VolumeFlowRateValue;
        attribute ratedPressure : PressureValue;
        
        port waterInlet : WaterInletPort;
        port waterOutlet : WaterOutletPort;
        
        action def PumpWater {
            in driveTorque : TorqueValue;
            in rotationSpeed : AngularVelocityValue;
            in inletPressure : PressureValue;
            in waterIn : Water;
            out outletPressure : PressureValue;
            out flowRate : VolumeFlowRateValue;
            out waterOut : Water;
        }
    }
    
    part def PressureSensor {
        attribute measurementRange : PressureValue;
        attribute accuracy : Real;
        
        action def MeasurePressure {
            in actualPressure : PressureValue;
            out measuredValue : PressureValue;
        }
    }
    
    part def FlowMeter {
        attribute measurementRange : VolumeFlowRateValue;
        attribute accuracy : Real;
        
        action def MeasureFlow {
            in actualFlow : VolumeFlowRateValue;
            out measuredValue : VolumeFlowRateValue;
        }
    }
    
    part def LevelSensor {
        attribute measurementRange : LengthValue;
        attribute accuracy : Real;
        
        action def MeasureLevel {
            in actualLevel : LengthValue;
            out measuredValue : LengthValue;
        }
    }
    
    part def PumpController {
        attribute targetPressure : PressureValue;
        attribute targetFlowRate : VolumeFlowRateValue;
        attribute minReservoirLevel : LengthValue;
        attribute currentSpeedCommand : AngularVelocityValue;
        
        port controlOutput : ControlPort;
        
        action def RegulateOperation {
            in currentPressure : PressureValue;
            in currentFlow : VolumeFlowRateValue;
            in reservoirLevel : LengthValue;
            out speedCommand : AngularVelocityValue;
        }
    }
    
    part def SzczecinWaterPumpStation {
        attribute stationCapacity : VolumeFlowRateValue;
        attribute operatingPressure : PressureValue;
        
        part sourceReservoir : IntakeReservoir {
            attribute :>> capacity = 8000.0 [m3];
            attribute :>> maxLevel = 12.0 [m];
            attribute :>> minLevel = 3.0 [m];
        }
        
        part mainPump : CentrifugalPump {
            attribute :>> ratedFlowRate = 600.0 [m3/h];
            attribute :>> ratedPressure = 700000.0 [Pa];
            attribute :>> impellerDiameter = 0.45 [m];
        }
        
        part driveMotor : ElectricMotor {
            attribute :>> ratedPower = 90000.0 [W];
            attribute :>> efficiency = 0.93;
        }
        
        part cityDistribution : DistributionNetwork {
            attribute :>> requiredPressure = 650000.0 [Pa];
            attribute :>> demandFlowRate = 550.0 [m3/h];
        }
        
        part outletPressureSensor : PressureSensor {
            attribute :>> accuracy = 0.015;
            attribute :>> measurementRange = 1000000.0 [Pa];
        }
        
        part outletFlowMeter : FlowMeter {
            attribute :>> accuracy = 0.02;
            attribute :>> measurementRange = 800.0 [m3/h];
        }
        
        part reservoirLevelSensor : LevelSensor {
            attribute :>> accuracy = 0.01;
            attribute :>> measurementRange = 15.0 [m];
        }
        
        part systemController : PumpController {
            attribute :>> targetPressure = 650000.0 [Pa];
            attribute :>> targetFlowRate = 550.0 [m3/h];
            attribute :>> minReservoirLevel = 3.5 [m];
        }
        
        connect sourceReservoir.outlet to mainPump.waterInlet;
        connect mainPump.waterOutlet to cityDistribution.inlet;
        
        item flow from sourceReservoir.outlet.water to mainPump.waterInlet.water;
        item flow from mainPump.waterOutlet.water to cityDistribution.inlet.water;
        
        perform action operatePumpStation : OperatePumpStation {
            in sourceLevel = sourceReservoir.currentLevel;
            in demandPressure = cityDistribution.requiredPressure;
            in demandFlow = cityDistribution.demandFlowRate;
            out deliveredFlow : VolumeFlowRateValue;
            out deliveredPressure : PressureValue;
        }
    }
    
    action def OperatePumpStation {
        in sourceLevel : LengthValue;
        in demandPressure : PressureValue;
        in demandFlow : VolumeFlowRateValue;
        out deliveredFlow : VolumeFlowRateValue;
        out deliveredPressure : PressureValue;
        
        loop {
            accept startOperation : PumpStartCommand;
            then merge continuousOperation;
            then action monitorReservoir {
                in level : LengthValue = sourceLevel;
                out measuredLevel : LengthValue;
            }
            then action measureOutletPressure {
                out currentPressure : PressureValue;
            }
            then action measureOutletFlow {
                out currentFlow : VolumeFlowRateValue;
            }
            then action controlPumpSpeed {
                in reservoirLevel : LengthValue = monitorReservoir.measuredLevel;
                in feedbackPressure : PressureValue = measureOutletPressure.currentPressure;
                in feedbackFlow : VolumeFlowRateValue = measureOutletFlow.currentFlow;
                in targetPressure : PressureValue = demandPressure;
                in targetFlow : VolumeFlowRateValue = demandFlow;
                out motorCommand : AngularVelocityValue;
            }
            then action driveMotor {
                in speedCommand : AngularVelocityValue = controlPumpSpeed.motorCommand;
                out motorTorque : TorqueValue;
                out motorSpeed : AngularVelocityValue;
            }
            then action pumpWater {
                in driveTorque : TorqueValue = driveMotor.motorTorque;
                in rotationSpeed : AngularVelocityValue = driveMotor.motorSpeed;
                out outletPressure : PressureValue;
                out outletFlow : VolumeFlowRateValue;
            }
            then assign deliveredPressure := pumpWater.outletPressure;
            then assign deliveredFlow := pumpWater.outletFlow;
            then continuousOperation;
            accept stopOperation : PumpStopCommand;
        }
    }
    
    requirement <'WPS-REQ-001'> waterSupplyRequirement {
        doc /* The Szczecin water pump station shall deliver water to the municipal distribution network 
               at a minimum pressure of 6.0 bar and a flow rate between 500 and 600 cubic meters per hour 
               to meet the city's water demand. */
        
        subject pumpStation : SzczecinWaterPumpStation;
        
        require constraint minimumPressureConstraint {
            pumpStation.operatePumpStation.deliveredPressure >= 600000.0 [Pa]
        }
        
        require constraint flowRateRangeConstraint {
            pumpStation.operatePumpStation.deliveredFlow >= 500.0 [m3/h] and 
            pumpStation.operatePumpStation.deliveredFlow <= 600.0 [m3/h]
        }
    }
    
    requirement <'WPS-REQ-002'> reservoirLevelRequirement {
        doc /* The intake reservoir level shall be maintained above 3.0 meters to ensure continuous 
               pump operation and prevent cavitation. */
        
        subject pumpStation : SzczecinWaterPumpStation;
        
        require constraint minimumLevelConstraint {
            pumpStation.sourceReservoir.currentLevel >= 3.0 [m]
        }
    }
    
    requirement <'WPS-REQ-003'> energyEfficiencyRequirement {
        doc /* The pump station shall operate with a minimum overall system efficiency of 85% 
               to minimize energy consumption and operational costs. */
        
        subject pumpStation : SzczecinWaterPumpStation;
        
        require constraint efficiencyConstraint {
            pumpStation.driveMotor.efficiency >= 0.85
        }
    }
    
    requirement <'WPS-REQ-004'> systemReliabilityRequirement {
        doc /* The pump station shall provide continuous water supply with automated control, 
               real-time monitoring, and emergency shutdown capability to ensure reliable operation. */
        
        subject pumpStation : SzczecinWaterPumpStation;
        
        assume constraint controllerOperationalAssumption {
            pumpStation.systemController.targetPressure == 650000.0 [Pa]
        }
    }
    
    requirement szczecinPumpStationMission {
        doc /* The Szczecin water pump station shall reliably transfer water from the intake reservoir 
               to the municipal distribution network, maintaining required pressure and flow rates 
               while operating efficiently and safely to serve the city's water supply needs. */
        
        assume reservoirLevelRequirement;
        require waterSupplyRequirement;
        require energyEfficiencyRequirement;
        require systemReliabilityRequirement;
    }
}
