import React from 'react';
import { Link } from 'react-router-dom';

function Header() {
  return (
    <header className="App-header">
      <div className="logo">MongoFlow</div>
      <nav>
        <Link to="/">Dashboard</Link>
        <Link to="/items">Items</Link>
      </nav>
    </header>
  );
}

export default Header;
