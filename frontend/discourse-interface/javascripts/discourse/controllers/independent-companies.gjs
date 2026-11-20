import CompaniesController from "./companies.gjs";
import profileDirectoryController from "../lib/svdex-profile-directory-controller.gjs";
export default class IndependentCompaniesController extends profileDirectoryController(CompaniesController) {}
