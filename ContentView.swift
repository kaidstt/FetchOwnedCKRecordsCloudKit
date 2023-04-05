//
//  ContentView.swift
//  References
//
//  Created by Kai Major on 29/03/2023.
//

import SwiftUI
import CloudKit

//MARK: Example object to be saved to CloudKit
struct Dog: Hashable {
    let name: String
    let breed: String
    let age: Int
    let owner: CKRecord.Reference
    
    //Converting a fetched CKRecord into a dog struct
    static func fromRecord(_ record: CKRecord) -> Dog? {
        guard let name = record["name"] as? String else { return nil }
        guard let breed = record["breed"] as? String else { return nil }
        guard let age = record["age"] as? Int else { return nil }
        guard let owner = record["owner"] as? CKRecord.Reference else { return nil }
        
        return Dog(name: name, breed: breed, age: age, owner: owner)
    }
}

struct ContentView: View {
    private let database = CKContainer.default().publicCloudDatabase
    @State private var name: String = ""
    @State private var breed: String = ""
    @State private var age: Int = 0
    
    @State private var myRecordId: CKRecord.ID?
    @State private var myDogs: [Dog] = []
    
    func fetchMyDogs() {
        if let id = myRecordId {
            let matchingUser = CKRecord(recordType: CKRecord.SystemType.userRecord, recordID: id)
            let predicate = NSPredicate(format: "owner == %@", matchingUser)
            let query = CKQuery(recordType: "Dog", predicate: predicate)
            
            database.fetch(withQuery: query) { results in
                switch results {
                case .success(let result):
                    result.matchResults.compactMap { $0.1 }
                        .forEach {
                            switch $0 {
                            case .success(let record):
                                if let dog = Dog.fromRecord(record) {
                                    self.myDogs.append(dog)
                                }
                            case .failure(let error):
                                print(error)
                            }
                        }
                case .failure(let error):
                    print(error)
                }
            }
        }
    }
    
    func fetchRecordId() async {
        if let id = try? await CKContainer.default().userRecordID() {
            self.myRecordId = id
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Add Dog") {
                    TextField("Name", text: $name)
                    TextField("Breed", text: $breed)
                    Stepper("Age: \(self.age)", value: $age, in: 0...100)
                    Button("Add dog to database") {
                        let record = CKRecord(recordType: "Dog")
                        record["name"] = self.name
                        record["breed"] = self.breed
                        record["age"] = self.age
                        
                        if let id = myRecordId {
                            // action of deleteSelf means that if the owner record is deleted all their associated dogs will be too
                            let ownerReference = CKRecord.Reference(recordID: id, action: .deleteSelf)
                            record["owner"] = ownerReference
                        }
                        
                        database.save(record) { savedRecord, error in
                            if let error {
                                print(error)
                            } else {
                                print("Saved")
                            }
                        }
                    }
                }
                
                Section("My dogs") {
                    ForEach(myDogs, id: \.self) { dog in
                        Text(dog.name)
                    }
                }
            }
            .navigationTitle("My Dog")
            .task {
                await fetchRecordId()
                fetchMyDogs()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
