import ballerina/config;
import ballerina/http;
import ballerina/io;
import wso2/sonarqube6;
import wso2/github4;

function main(string... args) {

    json summary = check getLineCoverageSummary(1);
    io:println(summary);
}

function getLineCoverageSummary(int recordCount) returns json|error {

    endpoint github4:Client githubEP {
        clientConfig: {
            auth: {
                scheme: http:OAUTH2,
                accessToken: config:getAsString("GITHUB_TOKEN")
            }
        }
    };

    endpoint sonarqube6:Client sonarqubeEP {
        clientConfig: {
            url: config:getAsString("SONARQUBE_ENDPOINT"),
            auth: {
                scheme: http:BASIC_AUTH,
                username: config:getAsString("SONARQUBE_TOKEN"),
                password: ""
            }
        }
    };

    github4:Organization organization;
    var gitOrganizationResult = githubEP->getOrganization("repname");
    match gitOrganizationResult {
        github4:Organization org => {
            organization = org;
        }
        github4:GitClientError err => {
            return err;
        }
    }

    github4:RepositoryList repositoryList;
    var gitRepostoryResult = githubEP->getOrganizationRepositoryList(organization, recordCount);
    match gitRepostoryResult {
        github4:RepositoryList repoList => {
            repositoryList = repoList;
        }
        github4:GitClientError err => {
            return err;
        }
    }
    json summaryJson = [];
    foreach i, repo in repositoryList.getAllRepositories() {
        var sonarqubeProjectResult = sonarqubeEP->getProject(repo.name);
        match sonarqubeProjectResult {
            sonarqube6:Project project => {
                string lineCoverage = sonarqubeEP->getLineCoverage(untaint project.key) but { error err => "0.0%" };
                summaryJson[i] = { "name": repo.name, "coverage": lineCoverage };
            }
            error err => {
                summaryJson[i] = { "name": repo.name, "coverage": "Not defined" };
            }
        }
    }

    return summaryJson;
}
