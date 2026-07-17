package OilTerminalSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def OilGrade;
    attribute def CrudeOil :> OilGrade;
    attribute def RefinedProduct :> OilGrade;
    attribute def Diesel :> OilGrade;
    attribute def Gasoline :> OilGrade;
    
    attribute def OperationalMode {
        attribute receiving : Boolean;
        attribute storing : Boolean;
        attribute dispatching : Boolean;
        attribute blending : Boolean;
    }
    
    attribute def SafetyStatus {
        attribute pressureNormal : Boolean;
        attribute temperatureNormal : Boolean;
        attribute leakDetected : Boolean;
        attribute emergencyActive : Boolean;
    }
    
    attribute def TransferCommand {
        attribute sourceId : String;
        attribute destinationId : String;
        attribute volume : VolumeValue;
        attribute grade : OilGrade;
    }
    
    attribute def StartFillingSignal;
    attribute def TankFullSignal;
    attribute def StartDischargingSignal;
    attribute def TankEmptySignal;
    attribute def VesselArrivedSignal;
    attribute def ArmConnectedSignal;
    attribute def StartTransferSignal;
    attribute def TransferCompleteSignal;
    attribute def VesselDepartingSignal;
    attribute def ArmStowedSignal;
    attribute def AlertConditionSignal;
    attribute def CriticalConditionSignal;
    attribute def ConditionClearedSignal;
    attribute def SystemResetSignal;
    
    port def OilFlowPort {
        attribute flowRate : VolumeFlowRateValue;
        attribute pressure : PressureValue;
        attribute temperature : ThermodynamicTemperatureValue;
        attribute grade : OilGrade;
    }
    
    port def ControlPort {
        in attribute commands : TransferCommand[*];
        out attribute status : SafetyStatus;
        out attribute mode : OperationalMode;
    }
    
    port def VesselConnectionPort {
        attribute connected : Boolean;
        attribute vesselCapacity : VolumeValue;
        port oilInterface : OilFlowPort;
    }
    
    part def StorageTank {
        attribute tankId : String;
        attribute capacity : VolumeValue;
        attribute currentLevel : VolumeValue;
        attribute storedGrade : OilGrade;
        attribute maxPressure : PressureValue;
        attribute currentPressure : PressureValue;
        attribute currentTemperature : ThermodynamicTemperatureValue;
        
        port inlet : OilFlowPort;
        port outlet : OilFlowPort;
        port control : ControlPort;
        
        assert constraint capacityLimit {
            currentLevel <= capacity
        }
        
        assert constraint pressureSafety {
            currentPressure <= maxPressure
        }
        
        state tankStateMachine {
            entry; then empty;
            
            state empty {
                entry assign currentLevel := 0.0;
            }
            
            transition empty_to_filling
                first empty
                accept startFilling : StartFillingSignal
                then filling;
            
            state filling {
                do action fillTank;
            }
            
            transition filling_to_full
                first filling
                accept tankFull : TankFullSignal
                then full;
            
            state full {
                entry assign currentLevel := capacity;
            }
            
            transition full_to_discharging
                first full
                accept startDischarging : StartDischargingSignal
                then discharging;
            
            state discharging {
                do action dischargeTank;
            }
            
            transition discharging_to_empty
                first discharging
                accept tankEmpty : TankEmptySignal
                then empty;
        }
    }
    
    part def PumpingStation {
        attribute stationId : String;
        attribute maxFlowRate : VolumeFlowRateValue;
        attribute operational : Boolean;
        attribute powerConsumption : PowerValue;
        
        port suction : OilFlowPort;
        port discharge : OilFlowPort;
        port control : ControlPort;
        
        perform action pumpOil {
            in requestedRate : VolumeFlowRateValue;
            out actualRate : VolumeFlowRateValue;
            
            assert constraint flowLimit {
                actualRate <= maxFlowRate
            }
        }
    }
    
    part def PipelineSegment {
        attribute segmentId : String;
        attribute length : LengthValue;
        attribute diameter : LengthValue;
        attribute maxPressure : PressureValue;
        attribute material : String;
        
        port inlet : OilFlowPort;
        port outlet : OilFlowPort;
        
        perform action transportOil {
            in inletFlow : VolumeFlowRateValue;
            in inletPressure : PressureValue;
            out outletFlow : VolumeFlowRateValue;
            out outletPressure : PressureValue;
            out pressureDrop : PressureValue;
        }
    }
    
    part def LoadingArm {
        attribute armId : String;
        attribute maxLoadRate : VolumeFlowRateValue;
        attribute connected : Boolean;
        attribute armPosition : String;
        
        port terminalSide : OilFlowPort;
        port vesselSide : OilFlowPort;
        port control : ControlPort;
        
        state armStateMachine {
            entry; then stowed;
            
            state stowed;
            
            transition stowed_to_connecting
                first stowed
                accept vesselArrived : VesselArrivedSignal
                then connecting;
            
            state connecting {
                do action extendArm;
            }
            
            transition connecting_to_connected
                first connecting
                accept armConnected : ArmConnectedSignal
                then connected;
            
            state connected;
            
            transition connected_to_transferring
                first connected
                accept startTransfer : StartTransferSignal
                then transferring;
            
            state transferring {
                do action transferOil;
            }
            
            transition transferring_to_connected
                first transferring
                accept transferComplete : TransferCompleteSignal
                then connected;
            
            transition connected_to_disconnecting
                first connected
                accept vesselDeparting : VesselDepartingSignal
                then disconnecting;
            
            state disconnecting {
                do action retractArm;
            }
            
            transition disconnecting_to_stowed
                first disconnecting
                accept armStowed : ArmStowedSignal
                then stowed;
        }
    }
    
    part def SafetyMonitoringSystem {
        attribute systemId : String;
        attribute emergencyShutdownActive : Boolean;
        attribute leakDetectionEnabled : Boolean;
        
        port monitoring : ControlPort[*];
        
        perform action monitorSafety {
            in tankStatus : SafetyStatus[*];
            in pipelineStatus : SafetyStatus[*];
            out overallStatus : SafetyStatus;
            out shutdownRequired : Boolean;
            
            first start;
            then merge continueMonitoring;
            
            then action checkConditions {
                in tankSafety : SafetyStatus[*];
                in pipelineSafety : SafetyStatus[*];
                out hazardDetected : Boolean;
            }
            
            then decide;
                if checkConditions.hazardDetected then initiateShutdown;
                else continueMonitoring;
            
            action initiateShutdown {
                assign emergencyShutdownActive := true;
            }
            then done;
        }
        
        state safetyStateMachine {
            entry; then normal;
            
            state normal {
                entry assign emergencyShutdownActive := false;
            }
            
            transition normal_to_alert
                first normal
                accept alertCondition : AlertConditionSignal
                then alert;
            
            state alert {
                entry assign leakDetectionEnabled := true;
            }
            
            transition alert_to_emergency
                first alert
                accept criticalCondition : CriticalConditionSignal
                then emergency;
            
            transition alert_to_normal
                first alert
                accept conditionCleared : ConditionClearedSignal
                then normal;
            
            state emergency {
                entry assign emergencyShutdownActive := true;
                do action executeEmergencyShutdown;
            }
            
            transition emergency_to_normal
                first emergency
                accept systemReset : SystemResetSignal
                then normal;
        }
    }
    
    part def MeteringSystem {
        attribute meteringId : String;
        attribute accuracy : Real;
        attribute calibrationDate : String;
        
        port flowInput : OilFlowPort;
        
        perform action measureVolume {
            in flowRate : VolumeFlowRateValue;
            in duration : TimeValue;
            out totalVolume : VolumeValue;
            out averageFlowRate : VolumeFlowRateValue;
        }
    }
    
    part def ManifoldSystem {
        attribute manifoldId : String;
        attribute numberOfConnections : Integer;
        
        port mainInlet : OilFlowPort;
        port outlets : OilFlowPort[*];
        
        perform action distributeFlow {
            in inletFlow : VolumeFlowRateValue;
            out outletFlows : VolumeFlowRateValue[*];
        }
    }
    
    action def ReceiveOilFromVessel {
        in vesselCapacity : VolumeValue;
        in oilGrade : OilGrade;
        in targetTankId : String;
        in transferRate : VolumeFlowRateValue;
        out transferredVolume : VolumeValue;
        out transferComplete : Boolean;
        
        first start;
        then action connectVessel;
        then action startPumping {
            in rate = transferRate;
        }
        then merge monitorTransfer;
        
        then action checkProgress {
            in currentVolume : VolumeValue;
            in targetVolume : VolumeValue;
            out complete : Boolean;
        }
        
        then decide;
            if checkProgress.complete then stopPumping;
            else monitorTransfer;
        
        action stopPumping;
        then action disconnectVessel;
        then assign transferComplete := true;
        then done;
    }
    
    action def TransferBetweenTanks {
        in sourceTankId : String;
        in destinationTankId : String;
        in volumeToTransfer : VolumeValue;
        in transferRate : VolumeFlowRateValue;
        out actualVolume : VolumeValue;
        out transferSuccess : Boolean;
        
        first start;
        then action openValves;
        then action activatePump {
            in rate = transferRate;
        }
        then merge transferLoop;
        
        then action monitorVolume {
            in transferred : VolumeValue;
            in target : VolumeValue;
            out remaining : VolumeValue;
        }
        
        then decide;
            if monitorVolume.remaining > 0.0 then transferLoop;
            else completeTransfer;
        
        action completeTransfer {
            first action deactivatePump;
            then action closeValves;
            then assign transferSuccess := true;
        }
        then done;
    }
    
    action def DispatchOilToPipeline {
        in sourceTankId : String;
        in requestedVolume : VolumeValue;
        in oilGrade : OilGrade;
        in dispatchRate : VolumeFlowRateValue;
        out dispatchedVolume : VolumeValue;
        out dispatchComplete : Boolean;
    }
    
    action def BlendOilProducts {
        in sourceTank1Id : String;
        in sourceTank2Id : String;
        in blendRatio : Real;
        in destinationTankId : String;
        out blendedVolume : VolumeValue;
        out blendSuccess : Boolean;
    }
    
    connection def OilFlowConnection {
        end source : OilFlowPort;
        end destination : OilFlowPort;
    }
    
    connection def ControlConnection {
        end controller : ControlPort;
        end controlled : ControlPort;
    }
    
    part def OilTerminal {
        doc /*
            An integrated oil terminal facility for receiving crude oil and refined petroleum products
            from marine vessels and pipelines, storing them in segregated tank farms, performing
            blending operations when required, and dispatching products to distribution networks.
            The terminal ensures safe, efficient, and environmentally compliant handling of petroleum
            products through automated control systems and continuous safety monitoring.
        */
        
        attribute terminalName : String;
        attribute totalStorageCapacity : VolumeValue;
        attribute dailyThroughput : VolumeValue;
        attribute operationalStatus : OperationalMode;
        
        part crudeStorageTanks : StorageTank[6] {
            attribute :>> capacity = 100000.0;
            attribute :>> storedGrade = CrudeOil;
            attribute :>> maxPressure = 3.0;
        }
        
        part refinedProductTanks : StorageTank[8] {
            attribute :>> capacity = 50000.0;
            attribute :>> storedGrade = RefinedProduct;
            attribute :>> maxPressure = 2.5;
        }
        
        part dieselTanks : StorageTank[4] {
            attribute :>> capacity = 40000.0;
            attribute :>> storedGrade = Diesel;
            attribute :>> maxPressure = 2.0;
        }
        
        part gasolineTanks : StorageTank[4] {
            attribute :>> capacity = 40000.0;
            attribute :>> storedGrade = Gasoline;
            attribute :>> maxPressure = 2.0;
        }
        
        part marinePumpingStation : PumpingStation {
            attribute :>> maxFlowRate = 5000.0;
            attribute :>> operational = true;
            attribute :>> powerConsumption = 2500.0;
        }
        
        part transferPumps : PumpingStation[8] {
            attribute :>> maxFlowRate = 2000.0;
            attribute :>> operational = true;
            attribute :>> powerConsumption = 800.0;
        }
        
        part dispatchPumps : PumpingStation[4] {
            attribute :>> maxFlowRate = 3000.0;
            attribute :>> operational = true;
            attribute :>> powerConsumption = 1200.0;
        }
        
        part receivingPipelines : PipelineSegment[6] {
            attribute :>> diameter = 0.6;
            attribute :>> maxPressure = 12.0;
            attribute :>> material = "Carbon Steel";
        }
        
        part transferPipelines : PipelineSegment[16] {
            attribute :>> diameter = 0.4;
            attribute :>> maxPressure = 10.0;
            attribute :>> material = "Carbon Steel";
        }
        
        part dispatchPipelines : PipelineSegment[8] {
            attribute :>> diameter = 0.5;
            attribute :>> maxPressure = 15.0;
            attribute :>> material = "Stainless Steel";
        }
        
        part loadingArms : LoadingArm[6] {
            attribute :>> maxLoadRate = 4000.0;
            attribute :>> connected = false;
        }
        
        part safetySystem : SafetyMonitoringSystem {
            attribute :>> leakDetectionEnabled = true;
            attribute :>> emergencyShutdownActive = false;
        }
        
        part meteringStations : MeteringSystem[12] {
            attribute :>> accuracy = 0.25;
        }
        
        part receivingManifold : ManifoldSystem {
            attribute :>> numberOfConnections = 6;
        }
        
        part dispatchManifold : ManifoldSystem {
            attribute :>> numberOfConnections = 8;
        }
        
        connection vesselToArm : OilFlowConnection[6]
            connect loadingArms.vesselSide to loadingArms.terminalSide;
        
        connection armToPump : OilFlowConnection
            connect loadingArms[1].terminalSide to marinePumpingStation.suction;
        
        connection pumpToManifold : OilFlowConnection
            connect marinePumpingStation.discharge to receivingManifold.mainInlet;
        
        connection manifoldToPipeline : OilFlowConnection[6]
            connect receivingManifold.outlets to receivingPipelines.inlet;
        
        connection pipelineToTank : OilFlowConnection[6]
            connect receivingPipelines.outlet to crudeStorageTanks.inlet;
        
        connection tankToTransferPump : OilFlowConnection[8]
            connect refinedProductTanks.outlet to transferPumps.suction;
        
        connection transferPumpToPipeline : OilFlowConnection[8]
            connect transferPumps.discharge to transferPipelines.inlet;
        
        connection tankToDispatchPump : OilFlowConnection[4]
            connect dieselTanks.outlet to dispatchPumps.suction;
        
        connection dispatchPumpToManifold : OilFlowConnection[4]
            connect dispatchPumps.discharge to dispatchManifold.mainInlet;
        
        connection manifoldToDispatchPipeline : OilFlowConnection[8]
            connect dispatchManifold.outlets to dispatchPipelines.inlet;
        
        connection safetyMonitoringTanks : ControlConnection[22]
            connect crudeStorageTanks.control to safetySystem.monitoring;
        
        connection safetyMonitoringPumps : ControlConnection[12]
            connect marinePumpingStation.control to safetySystem.monitoring;
        
        perform action operateTerminal {
            doc /*
                Primary operational function: Continuously manage the receipt of petroleum products
                from marine vessels through loading arms, pump the products through metering systems
                into appropriate storage tanks based on product grade and specifications, perform
                inter-tank transfers and blending operations as required, and dispatch products to
                distribution pipelines or loading facilities. All operations are conducted under
                continuous safety monitoring with automated emergency shutdown capabilities.
            */
            
            first start;
            then merge operationalLoop;
            
            then action receiveVessel : ReceiveOilFromVessel {
                in vesselCapacity = 150000.0;
                in oilGrade = CrudeOil;
                in targetTankId = "CRUDE-01";
                in transferRate = 4500.0;
                out transferredVolume;
                out transferComplete;
            }
            
            then decide;
                if receiveVessel.transferComplete then processProducts;
                else operationalLoop;
            
            action processProducts {
                first action internalTransfer : TransferBetweenTanks {
                    in sourceTankId = "CRUDE-01";
                    in destinationTankId = "REFINED-01";
                    in volumeToTransfer = 50000.0;
                    in transferRate = 1800.0;
                    out actualVolume;
                    out transferSuccess;
                }
                
                then action blendOperation : BlendOilProducts {
                    in sourceTank1Id = "DIESEL-01";
                    in sourceTank2Id = "DIESEL-02";
                    in blendRatio = 0.6;
                    in destinationTankId = "REFINED-02";
                    out blendedVolume;
                    out blendSuccess;
                }
                
                then action dispatchProduct : DispatchOilToPipeline {
                    in sourceTankId = "REFINED-02";
                    in requestedVolume = 75000.0;
                    in oilGrade = RefinedProduct;
                    in dispatchRate = 2800.0;
                    out dispatchedVolume;
                    out dispatchComplete;
                }
            }
            
            then operationalLoop;
        }
    }
    
    part terminalFacility : OilTerminal {
        attribute :>> terminalName = "Coastal Petroleum Terminal";
        attribute :>> totalStorageCapacity = 1000000.0;
        attribute :>> dailyThroughput = 150000.0;
    }
    
    requirement def StorageCapacityRequirement {
        doc /*
            The oil terminal shall provide sufficient total storage capacity to accommodate
            anticipated daily throughput with adequate safety margins and operational flexibility
            for multiple product grades.
        */
        
        subject terminal : OilTerminal;
        
        require constraint minimumCapacity {
            terminal.totalStorageCapacity >= 800000.0
        }
    }
    
    requirement def SafetyMonitoringRequirement {
        doc /*
            The terminal shall maintain continuous automated safety monitoring of all critical
            systems including storage tanks, pipelines, and pumping stations, with capability
            for immediate emergency shutdown in response to hazardous conditions.
        */
        
        subject terminal : OilTerminal;
        
        require constraint continuousMonitoring {
            terminal.safetySystem.leakDetectionEnabled == true
        }
        
        require constraint emergencyResponse {
            terminal.safetySystem.emergencyShutdownActive implies 
                terminal.operationalStatus.receiving == false
        }
    }
    
    requirement def ThroughputRequirement {
        doc /*
            The terminal shall be capable of processing minimum daily throughput volumes
            to meet contractual obligations and operational demands while maintaining
            product quality and safety standards.
        */
        
        subject terminal : OilTerminal;
        
        require constraint minimumDailyThroughput {
            terminal.dailyThroughput >= 100000.0
        }
    }
    
    requirement def ProductSegregationRequirement {
        doc /*
            The terminal shall maintain strict segregation of different petroleum product
            grades in dedicated storage tanks to prevent cross-contamination and ensure
            product quality specifications are met.
        */
        
        subject terminal : OilTerminal;
        
        require constraint dedicatedCrudeStorage {
            terminal.crudeStorageTanks->forAll(tank | tank.storedGrade == CrudeOil)
        }
        
        require constraint dedicatedDieselStorage {
            terminal.dieselTanks->forAll(tank | tank.storedGrade == Diesel)
        }
    }
    
    requirement def MeteringAccuracyRequirement {
        doc /*
            All product transfers shall be measured with calibrated metering systems
            meeting industry accuracy standards for custody transfer and inventory
            management purposes.
        */
        
        subject terminal : OilTerminal;
        
        require constraint meteringPrecision {
            terminal.meteringStations->forAll(meter | meter.accuracy <= 0.25)
        }
    }
    
    requirement terminalOperationalRequirements {
        doc /*
            Comprehensive operational requirements for the oil terminal system ensuring
            safe, efficient, and compliant petroleum product handling operations.
        */
        
        subject terminalSystem : OilTerminal = terminalFacility;
        
        require capacityReq : StorageCapacityRequirement;
        require safetyReq : SafetyMonitoringRequirement;
        require throughputReq : ThroughputRequirement;
        require segregationReq : ProductSegregationRequirement;
        require meteringReq : MeteringAccuracyRequirement;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import OilTerminalSystem::*;

    action orchestrator {
        attribute testVesselCapacity : VolumeValue;
        attribute testOilGrade : OilGrade;
        attribute testTransferRate : VolumeFlowRateValue;
        attribute testCurrentVolume : VolumeValue;
        attribute testTargetVolume : VolumeValue;
        action actionProbe : ReceiveOilFromVessel {
            in vesselCapacity = testVesselCapacity;
            in oilGrade = testOilGrade;
            in targetTankId = "";
            in transferRate = testTransferRate;
            // TODO(human): unsupported input type for rate: unknown (missing declared type)
            in currentVolume = testCurrentVolume;
            in targetVolume = testTargetVolume;
        }
        first actionProbe;
    }
}
