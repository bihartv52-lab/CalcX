package com.example.demo.service;

import com.example.demo.model.User;
import org.springframework.stereotype.Service;

@Service
public class UserService {
    private final ExternalApiService externalApiService;
    
    public UserService(ExternalApiService externalApiService) {
        this.externalApiService = externalApiService;
    }
    
    public User getUserById(int id) {
        return externalApiService.fetchUserFromApi(id);
    }
}
