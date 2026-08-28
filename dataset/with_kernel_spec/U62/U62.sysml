package 'Esophageal Stent System' {
    private import ScalarValues::*;

    package Definitions {
        unit def mm;
        unit def N;
        
        value def LengthValue :> Real {
            unit mm;
        }
        value def ForceValue :> Real {
            unit N;
        }

        attribute def DeploymentSignal;
        attribute def ExpansionCompleteSignal;
        attribute def MigrationEvent;
        attribute def OcclusionEvent;
        attribute def ClearingSignal;
        attribute def RepositionSignal;

        item def FoodBolus;

        port def DeploymentPort {
            in deploy : DeploymentSignal;
        }
        port def DeliveryControlPort {
            out deploy : DeploymentSignal;
        }
        port def LumenPort {
            in incomingBolus : FoodBolus;
            out outgoingBolus : FoodBolus;
        }

        part def StentMesh {
            attribute material : String = "Nitinol";
            attribute radialForce : ForceValue;
        }

        part def StentCovering {
            attribute material : String = "Silicone";
            attribute coverageType : String = "Full";
        }

        part def Flange {
            attribute diameter : LengthValue;
            attribute anchorForce : ForceValue;
        }

        part def LumenChannel {
            attribute innerDiameter : LengthValue;
        }

        action def ExpandStent {
            out finalDiameter : LengthValue;
        }

        action def ProvidePatency {
            in bolus : FoodBolus;
            out passedBolus : FoodBolus;
        }

        action def DeployStent {
            out deploySignal : DeploymentSignal;
        }

        state def StentStates parallel {
            state operationalStates {
                entry; then compressed;
                state compressed;
                accept DeploymentSignal
                    then deploying;
                state deploying {
                    do action expandAction : ExpandStent;
                }
                accept ExpansionCompleteSignal
                    then fullyExpanded;
                state fullyExpanded {
                    do action patencyAction : ProvidePatency;
                }
            }
            state healthStates {
                entry; then patent;
                state patent;
                accept MigrationEvent
                    then migrated;
                accept OcclusionEvent
                    then occluded;
                state migrated;
                accept RepositionSignal
                    then patent;
                state occluded;
                accept ClearingSignal
                    then patent;
            }
        }

        part def EsophagealStent {
            part mesh : StentMesh;
            part covering : StentCovering;
            part proximalFlange : Flange;
            part distalFlange : Flange;
            part lumen : LumenChannel;

            port deploymentPort : DeploymentPort;
            port lumenPort : LumenPort;

            attribute targetDiameter : LengthValue;
            attribute currentDiameter : LengthValue;

            perform action expand : ExpandStent;
            perform action providePatency : ProvidePatency;
            exhibit state stentStates : StentStates;
        }

        part def Catheter {
            attribute length : LengthValue;
            attribute outerDiameter : LengthValue;
        }

        part def ReleaseMechanism {
            port controlPort : DeliveryControlPort;
        }

        part def DeliverySystem {
            part catheter : Catheter;
            part releaseMechanism : ReleaseMechanism;
            port deploymentPort : DeliveryControlPort;
            perform action deployStent : DeployStent;
        }

        requirement def RestoreSwallowing {
            subject stent : EsophagealStent;
            doc /* The stent shall hold the esophagus open to restore the patient's ability to swallow food and liquids. */
        }

        requirement def PreventMigration {
            subject stent : EsophagealStent;
            doc /* The proximal and distal flanges shall anchor against the esophageal wall to prevent stent migration. */
        }

        requirement def PreventTissueIngrowth {
            subject stent : EsophagealStent;
            doc /* The stent covering shall prevent tissue from growing into the mesh structure. */
        }

        requirement def MaintainPatency {
            subject stent : EsophagealStent;
            doc /* The stent shall maintain a patent lumen channel when fully expanded. */
        }
    }

    package Usages {
        private import Definitions::*;

        part esophagealStentSystem {
            part stent : EsophagealStent {
                attribute targetDiameter = 20.0 [mm];
                attribute currentDiameter = 0.0 [mm];

                part mesh : StentMesh {
                    radialForce = 8.0 [N];
                }
                part covering : StentCovering {
                    coverageType = "Full";
                }
                part proximalFlange : Flange {
                    diameter = 25.0 [mm];
                    anchorForce = 5.0 [N];
                }
                part distalFlange : Flange {
                    diameter = 25.0 [mm];
                    anchorForce = 5.0 [N];
                }
                part lumen : LumenChannel {
                    innerDiameter = 18.0 [mm];
                }

                port deploymentPort : DeploymentPort;
                port lumenPort : LumenPort;
            }

            part deliverySystem : DeliverySystem {
                part catheter : Catheter {
                    length = 1500.0 [mm];
                    outerDiameter = 8.0 [mm];
                }
                part releaseMechanism : ReleaseMechanism {
                    port controlPort : DeliveryControlPort;
                }
                port deploymentPort : DeliveryControlPort;

                bind deploymentPort = releaseMechanism.controlPort;
            }

            interface deploymentInterface
                connect deliverySystem.deploymentPort to stent.deploymentPort {
                flow deployFlow of DeploymentSignal
                    from deliverySystem.deploymentPort.deploy to stent.deploymentPort.deploy;
            }

            requirement restoreSwallowingReq : RestoreSwallowing {
                subject :>> stent = stent;
            }

            requirement preventMigrationReq : PreventMigration {
                subject :>> stent = stent;
            }

            requirement preventTissueIngrowthReq : PreventTissueIngrowth {
                subject :>> stent = stent;
            }

            requirement maintainPatencyReq : MaintainPatency {
                subject :>> stent = stent;
            }

            satisfy restoreSwallowingReq by stent.providePatency;
            satisfy preventMigrationReq by stent.proximalFlange;
            satisfy preventMigrationReq by stent.distalFlange;
            satisfy preventTissueIngrowthReq by stent.covering;
            satisfy maintainPatencyReq by stent.lumen;
        }
    }
}
