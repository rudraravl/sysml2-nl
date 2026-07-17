package CarIndustrySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def VehicleIdentificationNumber :> String;
    attribute def QualityMetric :> Real;
    attribute def ProductionCount :> Integer;
    
    value def ProductionTarget {
        attribute vehiclesPerDay : Real;
        attribute qualityThreshold : Real;
        attribute utilizationRate : Real;
    }
    
    item def SteelSheet {
        attribute thickness : LengthValue;
        attribute grade : String;
        attribute mass : MassValue;
    }
    
    item def BodyPanel {
        attribute panelType : String;
        attribute mass : MassValue;
        attribute surfaceArea : AreaValue;
    }
    
    item def PaintedBody {
        attribute color : String;
        attribute coatThickness : LengthValue;
        attribute mass : MassValue;
    }
    
    item def Powertrain {
        attribute engineType : String;
        attribute power : PowerValue;
        attribute mass : MassValue;
    }
    
    item def Chassis {
        attribute frameType : String;
        attribute mass : MassValue;
    }
    
    item def CompleteVehicle {
        attribute vin : VehicleIdentificationNumber;
        attribute totalMass : MassValue;
        attribute qualityScore : QualityMetric;
        attribute testStatus : Boolean;
    }
    
    enum def ManufacturingPhase {
        receiving;
        stamping;
        welding;
        painting;
        assembly;
        testing;
        shipping;
    }
    
    port def MaterialSupplyPort {
        in item steel : SteelSheet[*];
        in item powertrains : Powertrain[*];
    }
    
    port def ComponentTransferPort {
        out item panels : BodyPanel[*];
        in item panels : BodyPanel[*];
    }
    
    port def BodyTransferPort {
        out item bodies : PaintedBody[*];
        in item bodies : PaintedBody[*];
    }
    
    port def VehicleOutputPort {
        out item vehicles : CompleteVehicle[*];
    }
    
    port def QualityMonitorPort {
        in attribute measurements : QualityMetric[*];
        out attribute approvals : Boolean[*];
    }
    
    action def StampPanels {
        in item rawSteel : SteelSheet[*];
        in attribute pressForce : ForceValue;
        out item stampedPanels : BodyPanel[*];
    }
    
    action def WeldBody {
        in item panels : BodyPanel[*];
        in attribute weldTemperature : ThermodynamicTemperatureValue;
        out item weldedBody : Chassis;
    }
    
    action def ApplyPaint {
        in item bodyShell : Chassis;
        in attribute paintColor : String;
        out item paintedBody : PaintedBody;
    }
    
    action def InstallPowertrain {
        in item body : PaintedBody;
        in item engine : Powertrain;
        out item assembledVehicle : CompleteVehicle;
    }
    
    action def PerformQualityTest {
        in item vehicle : CompleteVehicle;
        out item testedVehicle : CompleteVehicle;
        out attribute testResult : QualityMetric;
    }
    
    action def ManufactureVehicle {
        in item steelSupply : SteelSheet[*];
        in item powertrainSupply : Powertrain[*];
        in attribute productionTarget : ProductionTarget;
        out item finishedVehicles : CompleteVehicle[*];
        
        first start;
        then merge productionLoop;
        
        then action checkMaterials {
            in item steel : SteelSheet[*] = steelSupply;
            in item powertrains : Powertrain[*] = powertrainSupply;
            out attribute materialsReady : Boolean;
        }
        
        then decide;
            if checkMaterials.materialsReady then beginProduction;
            if not checkMaterials.materialsReady then waitForSupply;
        
        action waitForSupply {
            in attribute delay : DurationValue;
        }
        then productionLoop;
        
        action beginProduction {
            action stamping : StampPanels {
                in item rawSteel = steelSupply;
                in attribute pressForce = 8000.0 [SI::'N·k'];
                out item stampedPanels;
            }
            
            then action welding : WeldBody {
                in item panels = stamping.stampedPanels;
                in attribute weldTemperature = 1900.0 [SI::K];
                out item weldedBody;
            }
            
            then action painting : ApplyPaint {
                in item bodyShell = welding.weldedBody;
                in attribute paintColor = "Silver";
                out item paintedBody;
            }
            
            then action assembly : InstallPowertrain {
                in item body = painting.paintedBody;
                in item engine = powertrainSupply->at(1);
                out item assembledVehicle;
            }
            
            then action testing : PerformQualityTest {
                in item vehicle = assembly.assembledVehicle;
                out item testedVehicle;
                out attribute testResult;
            }
            
            then decide;
                if testing.testResult >= productionTarget.qualityThreshold then acceptVehicle;
                if testing.testResult < productionTarget.qualityThreshold then rejectVehicle;
            
            action acceptVehicle {
                then assign finishedVehicles := finishedVehicles->including(testing.testedVehicle);
            }
            then productionLoop;
            
            action rejectVehicle;
            then productionLoop;
        }
    }
    
    state def ProductionLineState {
        entry; then offline;
        
        state offline;
        accept at startupSignal
        then operational;
        
        state operational {
            state receiving;
            accept when materialsAvailable
            then processing;
            
            state processing {
                state stamping;
                accept when stampingComplete
                then welding;
                
                state welding;
                accept when weldingComplete
                then painting;
                
                state painting;
                accept when paintingComplete
                then assembly;
                
                state assembly;
                accept when assemblyComplete
                then testing;
                
                state testing;
                accept when testingComplete
                then shipping;
                
                state shipping;
            }
            accept when shiftComplete
            then receiving;
        }
        accept at shutdownSignal
        then maintenance;
        
        state maintenance;
        accept at maintenanceComplete
        then offline;
    }
    
    part def StampingPress {
        port materialInput : MaterialSupplyPort;
        port panelOutput : ComponentTransferPort;
        
        attribute pressCapacity : ForceValue;
        attribute cycleTime : DurationValue;
        attribute operatingTemperature : ThermodynamicTemperatureValue;
        
        perform action stampOperation : StampPanels;
    }
    
    part def WeldingRobot {
        port panelInput : ComponentTransferPort;
        port bodyOutput : BodyTransferPort;
        
        attribute weldingCurrent : ElectricCurrentValue;
        attribute weldSpeed : SpeedValue;
        attribute numberOfArms : Integer;
        
        perform action weldOperation : WeldBody;
    }
    
    part def PaintBooth {
        port bodyInput : BodyTransferPort;
        port bodyOutput : BodyTransferPort;
        
        attribute sprayPressure : PressureValue;
        attribute boothTemperature : ThermodynamicTemperatureValue;
        attribute cureTime : DurationValue;
        
        perform action paintOperation : ApplyPaint;
    }
    
    part def AssemblyStation {
        port bodyInput : BodyTransferPort;
        port powertrainInput : MaterialSupplyPort;
        port vehicleOutput : VehicleOutputPort;
        
        attribute stationCount : Integer;
        attribute assemblyTime : DurationValue;
        
        perform action assemblyOperation : InstallPowertrain;
    }
    
    part def TestingFacility {
        port vehicleInput : VehicleOutputPort;
        port vehicleOutput : VehicleOutputPort;
        port qualityMonitor : QualityMonitorPort;
        
        attribute testDuration : DurationValue;
        attribute passThreshold : QualityMetric;
        
        perform action testOperation : PerformQualityTest;
    }
    
    requirement def ProductionCapabilityRequirement {
        doc /* The manufacturing system shall produce vehicles at the specified daily rate. */
        
        subject factory : VehicleManufacturingPlant;
        
        require constraint {
            factory.dailyProduction >= factory.targetProduction.vehiclesPerDay
        }
    }
    
    requirement def QualityAssuranceRequirement {
        doc /* All vehicles shall meet minimum quality standards before delivery. */
        
        subject vehicle : CompleteVehicle;
        
        require constraint {
            vehicle.qualityScore >= 90.0
        }
    }
    
    requirement def EfficiencyRequirement {
        doc /* The manufacturing plant shall maintain minimum operational efficiency. */
        
        subject factory : VehicleManufacturingPlant;
        
        require constraint {
            factory.operationalEfficiency >= factory.targetProduction.utilizationRate
        }
    }
    
    requirement <'MFG-001'> vehicleManufacturingRequirements {
        doc /* The vehicle manufacturing system shall efficiently produce high-quality vehicles meeting all specifications. */
        
        require productionCapability : ProductionCapabilityRequirement;
        require qualityAssurance : QualityAssuranceRequirement;
        require efficiency : EfficiencyRequirement;
    }
    
    part def VehicleManufacturingPlant {
        attribute targetProduction : ProductionTarget;
        attribute dailyProduction : ProductionCount;
        attribute operationalEfficiency : Real;
        
        part stampingDepartment : StampingPress[6] {
            attribute pressCapacity = 10000.0 [SI::'N·k'];
            attribute cycleTime = 60.0 [SI::s];
            attribute operatingTemperature = 293.15 [SI::K];
        }
        
        part weldingDepartment : WeldingRobot[8] {
            attribute weldingCurrent = 250.0 [SI::A];
            attribute weldSpeed = 0.8 [SI::'m/s'];
            attribute numberOfArms = 6;
        }
        
        part paintingDepartment : PaintBooth[4] {
            attribute sprayPressure = 300.0 [SI::kPa];
            attribute boothTemperature = 333.15 [SI::K];
            attribute cureTime = 7200.0 [SI::s];
        }
        
        part finalAssembly : AssemblyStation[3] {
            attribute stationCount = 18;
            attribute assemblyTime = 14400.0 [SI::s];
        }
        
        part qualityTesting : TestingFacility[2] {
            attribute testDuration = 3600.0 [SI::s];
            attribute passThreshold = 90.0;
        }
        
        connection stampingToWelding connect 
            stampingDepartment.panelOutput to weldingDepartment.panelInput;
        
        connection weldingToPainting connect 
            weldingDepartment.bodyOutput to paintingDepartment.bodyInput;
        
        connection paintingToAssembly connect 
            paintingDepartment.bodyOutput to finalAssembly.bodyInput;
        
        connection assemblyToTesting connect 
            finalAssembly.vehicleOutput to qualityTesting.vehicleInput;
        
        perform action productionProcess : ManufactureVehicle {
            in attribute productionTarget : ProductionTarget {
                attribute vehiclesPerDay = 500.0;
                attribute qualityThreshold = 90.0;
                attribute utilizationRate = 0.85;
            }
            out item finishedVehicles;
        }
        
        exhibit state plantState : ProductionLineState;
        
        satisfy vehicleManufacturingRequirements by self;
    }
    
    part manufacturingPlant : VehicleManufacturingPlant {
        attribute targetProduction : ProductionTarget {
            attribute vehiclesPerDay = 500.0;
            attribute qualityThreshold = 90.0;
            attribute utilizationRate = 0.85;
        }
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import CarIndustrySystem::*;

    part testSubject : VehicleManufacturingPlant {
        exhibit state plantState : ProductionLineState;
    }

    action orchestrator {
        attribute testPressForce : ForceValue;
        action stampingProbe : StampPanels {
            // TODO(human): unsupported input type for rawSteel: SteelSheet[*] (type is not a primitive, enum, extracted payload def, or known value type)
            in pressForce = testPressForce;
        }
        first stampingProbe;
    }
}
